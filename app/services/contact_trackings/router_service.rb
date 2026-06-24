# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar
# ================================================================================
# proyecto@contact_tracking - ROUTER DE INTENCIONES
# ================================================================================
# Servicio: ContactTrackings::RouterService
# Versión: 1.0.0
# Fecha: 2026-05-08
#
# RESPONSABILIDAD:
#   Clasificar la intención de un mensaje entrante dentro de un seguimiento activo.
#   Llama a GPT con un prompt de clasificación y retorna una ruta simbólica.
#
# RUTAS POSIBLES:
#   :rejected         → El cliente rechaza / no le interesa / pide que no le contacten
#   :interested       → El cliente muestra interés claro en avanzar
#   :reschedule       → El cliente solicita cambiar la fecha/hora de contacto
#   :book_appointment → El cliente pide explícitamente agendar una cita, reunión o llamada
#   :cancel_appointment → El cliente pide cancelar (anular) una cita ya agendada
#   :kbase            → El cliente tiene una duda que requiere búsqueda en base de conocimiento
#   :botseller        → El mensaje es un comando o consulta para el bot de ventas
#   :tracking         → Conversación normal, sin acción especial (default)
#
# RETORNO:
#   {
#     route:               Symbol,  # una de las rutas anteriores
#     confidence:          Float,   # 0.0 - 1.0
#     method:              String,  # 'ai' | 'error' | 'no_key'
#     appointment_action:  Symbol,  # :query | :book_new | :move | :cancel | nil (sobre la cita)
#     reschedule_data:     Hash     # cuando hay fecha/hora (reschedule o move)
#   }
#
# APPOINTMENT-AWARE (proyecto@bot_seguimiento_calendar):
#   El clasificador recibe el ESTADO DE LA CITA del contacto (si ya tiene una y cuándo) y
#   decide una `appointment_action` concreta. Esto evita parchar con guards y permite
#   distinguir "consultar / mover / cancelar la mía" de "agendar una nueva".
#
# ACTIVACIÓN:
#   Solo se usa cuando TRACKING_DETECT_INTENT=true en variables de entorno.
# ================================================================================

module ContactTrackings
  class RouterService
    VALID_ROUTES = %w[rejected interested reschedule book_appointment cancel_appointment kbase botseller tracking].freeze
    VALID_APPOINTMENT_ACTIONS = %w[query book_new move cancel].freeze

    CLASSIFICATION_PROMPT = <<~PROMPT.strip
      Eres un clasificador de intenciones. Analiza el mensaje del cliente y responde
      ÚNICAMENTE con un JSON con la siguiente estructura, sin explicación adicional:

      {
        "intent": "<una de: rejected | interested | reschedule | book_appointment | cancel_appointment | kbase | tracking>",
        "confidence": <número entre 0.0 y 1.0>,
        "appointment_action": "<null | query | book_new | move | cancel>",
        "reschedule_data": {
          "relative_minutes": <null o número>,
          "relative_hours":   <null o número>,
          "relative_days":    <null o número>,
          "specific_date":    <null o "YYYY-MM-DD">,
          "specific_time":    <null o "HH:MM">,
          "time_of_day":      <null | "morning" | "afternoon" | "evening">,
          "natural":          <null o descripción natural como "mañana a las 3pm">
        }
      }

      Definiciones:
      - "rejected":          el cliente rechaza la oferta, dice que no le interesa, pide que no le contacten o similar.
      - "interested":        el cliente muestra interés explícito en avanzar o comprar, pero SIN pedir una cita concreta.
      - "reschedule":        el cliente solicita cambiar cuándo se le contacta (mañana, en 2 horas, el lunes, etc.).
      - "book_appointment":  el cliente pide explícitamente agendar una cita, reunión, llamada o quiere saber
                             cuándo hay disponibilidad de horarios. Ejemplos: "quiero agendar una cita",
                             "podemos hacer una llamada?", "cuándo tienen disponibilidad", "me gustaría reunirme".
      - "cancel_appointment": el cliente pide CANCELAR una cita YA agendada (no reagendar a otra hora, sino
                             anularla). Ejemplos: "quiero cancelar mi cita", "ya no voy a poder asistir",
                             "cancela la reunión", "anula la cita".
      - "kbase":             el cliente tiene una duda técnica, funcional, de proceso o pide ayuda/soporte que
                             requiere consultar una base de conocimiento. Incluye preguntas sobre cómo hacer algo,
                             errores, configuraciones, procesos, etc.
      - "tracking":          cualquier otro mensaje conversacional que no encaje en las categorías anteriores.

      "appointment_action" — SOLO sobre una CITA/reunión/llamada de calendario (NO el recordatorio
      del seguimiento). Decide mirando el ESTADO DE LA CITA de más abajo:
      - "query":    el cliente pregunta por su cita YA agendada (cuándo es, a qué hora, confirmar o
                    ver detalles). Solo válido si el contacto YA tiene una cita.
      - "book_new": el cliente quiere agendar una cita/reunión/llamada NUEVA.
      - "move":     el cliente quiere cambiar la fecha/hora de su cita YA agendada. Llena
                    "reschedule_data" con la nueva fecha/hora si la menciona.
      - "cancel":   el cliente quiere anular/cancelar su cita YA agendada.
      - null:       el mensaje NO trata sobre una cita de calendario.
      Si "appointment_action" no es null, prioriza esa acción para temas de cita.

      IMPORTANTE: Si el mensaje del cliente es una confirmación breve ("es correcto", "sí", "correcto",
      "así es", "exacto", etc.) y el historial reciente muestra que el bot acaba de pedir confirmación
      sobre una consulta técnica, clasifica como "kbase" para continuar respondiendo esa consulta.

      Llena "reschedule_data" cuando el cliente mencione una fecha/hora (para "reschedule" o para
      "appointment_action": "move"); si no menciona ninguna, déjalo en null.

      %{today}
      En "reschedule_data" expresá las fechas SIEMPRE como "specific_date" absoluta (YYYY-MM-DD),
      tomándola de la lista de "Próximas fechas" de arriba según el día que mencione el cliente
      (p. ej. "el próximo martes" → la fecha que figura como martes). NO calcules la fecha a mano:
      usá la que está en la lista. Para "ese mismo día" / "la misma fecha", usá la fecha de la cita
      actual de ESTADO DE LA CITA. Incluí "specific_time" (HH:MM 24h) solo cuando mencione una hora
      concreta. Si menciona una FRANJA sin hora exacta ("por la mañana/tarde/noche"), poné
      "time_of_day" (morning/afternoon/evening) y dejá "specific_time" en null.

      ESTADO DE LA CITA: %{appointment_state}

      Historial reciente de la conversación:
      %{recent_context}

      Objetivo del seguimiento: %{objective}
      Mensaje del cliente: "%{message}"
    PROMPT

    def initialize(tracking, message, api_key, kbase_available: false, botseller_available: false, recent_messages: '',
                   appointment_state: nil, current_date: nil)
      @tracking            = tracking
      @message             = message
      @api_key             = api_key
      @kbase_available     = kbase_available
      @botseller_available = botseller_available
      @recent_messages     = recent_messages
      @appointment_state   = appointment_state
      @current_date        = current_date
    end

    def classify
      raw = call_openai
      return fallback('no_response') if raw.blank?

      parsed = JSON.parse(raw)
      intent = parsed['intent'].to_s.strip.downcase

      unless VALID_ROUTES.include?(intent)
        Rails.logger.warn "[RouterService] ⚠️ Intención desconocida '#{intent}' → :tracking"
        return fallback('unknown_intent')
      end

      # Si la ruta es :kbase pero no hay base de conocimiento disponible → :tracking
      if intent == 'kbase' && !@kbase_available
        Rails.logger.info '[RouterService] 📚 :kbase solicitado pero kbase no disponible → :tracking'
        intent = 'tracking'
      end

      # Si la ruta es :botseller pero no está configurado → :tracking
      if intent == 'botseller' && !@botseller_available
        intent = 'tracking'
      end

      confidence = parsed['confidence'].to_f.clamp(0.0, 1.0)
      result = {
        route:              intent.to_sym,
        confidence:         confidence,
        method:             'ai',
        appointment_action: parse_appointment_action(parsed['appointment_action'])
      }

      result[:reschedule_data] = parse_reschedule_data(parsed['reschedule_data']) if parsed['reschedule_data'].present?

      Rails.logger.info "[RouterService] 🧭 Ruta: :#{intent} (conf: #{confidence.round(2)})" \
                        "#{result[:appointment_action] ? " · cita: #{result[:appointment_action]}" : ''}"
      result

    rescue JSON::ParserError => e
      Rails.logger.warn "[RouterService] ⚠️ JSON inválido: #{e.message} → :tracking"
      fallback('parse_error')
    rescue StandardError => e
      Rails.logger.error "[RouterService] ❌ Error: #{e.message}"
      fallback('error')
    end

    private

    def call_openai
      require 'net/http'
      require 'json'

      prompt = CLASSIFICATION_PROMPT % {
        objective:         @tracking.objective.truncate(200),
        message:           @message.content.truncate(400),
        recent_context:    @recent_messages.presence || '(sin historial previo)',
        appointment_state: @appointment_state.presence || 'El contacto no tiene ninguna cita agendada.',
        today:             @current_date.presence || Time.current.strftime('%Y-%m-%d (%A)')
      }

      uri               = URI('https://api.openai.com/v1/chat/completions')
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 10

      request                  = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type']  = 'application/json'
      request.body = {
        model:           'gpt-4o-mini',
        messages:        [{ role: 'user', content: prompt }],
        max_tokens:      300,
        temperature:     0.1,
        response_format: { type: 'json_object' }
      }.to_json

      response = http.request(request)
      JSON.parse(response.body).dig('choices', 0, 'message', 'content')
    end

    def parse_appointment_action(value)
      action = value.to_s.strip.downcase
      VALID_APPOINTMENT_ACTIONS.include?(action) ? action.to_sym : nil
    end

    def parse_reschedule_data(data)
      return {} if data.nil? || !data.is_a?(Hash)

      parsed = {
        relative_minutes: data['relative_minutes']&.to_i,
        relative_hours:   data['relative_hours']&.to_i,
        relative_days:    data['relative_days']&.to_i,
        specific_date:    data['specific_date'].presence,
        specific_time:    data['specific_time'].presence,
        time_of_day:      parse_time_of_day(data['time_of_day']),
        natural:          data['natural'].presence
      }.compact

      # `natural` (descripción legible) y `time_of_day` (franja sin día) no son, por sí solos,
      # una fecha accionable: sin un día/hora REAL no hay reagendado pedido, así que devolvemos
      # vacío para que el handler pregunte cuándo en vez de mover la cita a ciegas.
      parsed.except(:natural, :time_of_day).empty? ? {} : parsed
    end

    def parse_time_of_day(value)
      tod = value.to_s.strip.downcase
      %w[morning afternoon evening].include?(tod) ? tod : nil
    end

    def fallback(reason)
      {
        route:              :tracking,
        confidence:         1.0,
        method:             reason,
        appointment_action: nil
      }
    end
  end
end
