# frozen_string_literal: true

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
#   :rejected   → El cliente rechaza / no le interesa / pide que no le contacten
#   :interested → El cliente muestra interés claro en avanzar
#   :reschedule → El cliente solicita cambiar la fecha/hora de contacto
#   :kbase      → El cliente tiene una duda que requiere búsqueda en base de conocimiento
#   :botseller  → El mensaje es un comando o consulta para el bot de ventas
#   :tracking   → Conversación normal, sin acción especial (default)
#
# RETORNO:
#   {
#     route:          Symbol,  # una de las rutas anteriores
#     confidence:     Float,   # 0.0 - 1.0
#     method:         String,  # 'ai' | 'error' | 'no_key'
#     reschedule_data: Hash    # solo cuando route == :reschedule
#   }
#
# ACTIVACIÓN:
#   Solo se usa cuando TRACKING_DETECT_INTENT=true en variables de entorno.
# ================================================================================

module ContactTrackings
  class RouterService
    VALID_ROUTES = %w[rejected interested reschedule kbase botseller tracking].freeze

    CLASSIFICATION_PROMPT = <<~PROMPT.strip
      Eres un clasificador de intenciones. Analiza el mensaje del cliente y responde
      ÚNICAMENTE con un JSON con la siguiente estructura, sin explicación adicional:

      {
        "intent": "<una de: rejected | interested | reschedule | kbase | tracking>",
        "confidence": <número entre 0.0 y 1.0>,
        "reschedule_data": {
          "relative_minutes": <null o número>,
          "relative_hours":   <null o número>,
          "relative_days":    <null o número>,
          "specific_date":    <null o "YYYY-MM-DD">,
          "specific_time":    <null o "HH:MM">,
          "natural":          <null o descripción natural como "mañana a las 3pm">
        }
      }

      Definiciones:
      - "rejected":   el cliente rechaza la oferta, dice que no le interesa, pide que no le contacten o similar.
      - "interested": el cliente muestra interés explícito en avanzar, comprar, saber más, agendar reunión, etc.
      - "reschedule": el cliente solicita cambiar cuándo se le contacta (mañana, en 2 horas, el lunes, etc.).
      - "kbase":      el cliente tiene una duda técnica, funcional, de proceso o pide ayuda/soporte que requiere
                      consultar una base de conocimiento. Incluye preguntas sobre cómo hacer algo, errores,
                      configuraciones, procesos, etc.
      - "tracking":   cualquier otro mensaje conversacional que no encaje en las categorías anteriores.

      IMPORTANTE: Si el mensaje del cliente es una confirmación breve ("es correcto", "sí", "correcto",
      "así es", "exacto", etc.) y el historial reciente muestra que el bot acaba de pedir confirmación
      sobre una consulta técnica, clasifica como "kbase" para continuar respondiendo esa consulta.

      Si el intent NO es "reschedule", el campo "reschedule_data" debe ser null.

      Historial reciente de la conversación:
      %{recent_context}

      Objetivo del seguimiento: %{objective}
      Mensaje del cliente: "%{message}"
    PROMPT

    def initialize(tracking, message, api_key, kbase_available: false, botseller_available: false, recent_messages: '')
      @tracking            = tracking
      @message             = message
      @api_key             = api_key
      @kbase_available     = kbase_available
      @botseller_available = botseller_available
      @recent_messages     = recent_messages
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
        route:      intent.to_sym,
        confidence: confidence,
        method:     'ai'
      }

      result[:reschedule_data] = parse_reschedule_data(parsed['reschedule_data']) if intent == 'reschedule'

      Rails.logger.info "[RouterService] 🧭 Ruta: :#{intent} (confianza: #{confidence.round(2)})"
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
        objective:      @tracking.objective.truncate(200),
        message:        @message.content.truncate(400),
        recent_context: @recent_messages.presence || '(sin historial previo)'
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

    def parse_reschedule_data(data)
      return {} if data.nil? || !data.is_a?(Hash)

      {
        relative_minutes: data['relative_minutes']&.to_i,
        relative_hours:   data['relative_hours']&.to_i,
        relative_days:    data['relative_days']&.to_i,
        specific_date:    data['specific_date'].presence,
        specific_time:    data['specific_time'].presence,
        natural:          data['natural'].presence
      }.compact
    end

    def fallback(reason)
      {
        route:      :tracking,
        confidence: 1.0,
        method:     reason
      }
    end
  end
end
