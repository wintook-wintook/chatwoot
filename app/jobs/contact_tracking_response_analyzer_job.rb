# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - BOT DE REAGENDAMIENTO Y CANCELACIÓN INTELIGENTE
# ================================================================================
# Job: ContactTrackingResponseAnalyzerJob
# Descripción: Bot que detecta solicitudes de reagendamiento y rechazos automáticamente
#              con respuestas generadas por IA contextualizadas
# Versión: 6.4.0 - Con intención QUESTION y prompt complementario (#IF)
# Fecha: 2026-01-23
#
# FUNCIONALIDAD:
#   - Se ejecuta cuando el cliente envía un mensaje (incoming)
#   - REGLA 10: Ignora mensajes vacíos o sin texto
#   - REGLA 8 y 9: Ignora mensajes de cortesía sin contenido relevante
#   - Busca seguimientos activos para ese contacto
#   - Detecta la intención del mensaje en orden de prioridad
#   - Genera respuestas personalizadas con IA basadas en el contexto
#   - Toma acción según la intención detectada
#   - Envía respuestas automáticas al cliente
#
# INTENCIONES DETECTADAS (en orden de prioridad):
#   1. rejected: Cliente rechaza seguimiento → REGLA 12, 14 (Cancelar + Despedida + Nota privada)
#   2. interested: Cliente muestra interés → REGLA 13 (Completar + Notificar admin + NO auto-responder)
#   3. reschedule: Cliente solicita reagendar → REGLA 15, 16, 17, 27 (Extraer fecha + Reagendar + Confirmar)
#   4. question: Cliente pregunta sobre su seguimiento → Responder + #IF (NO modifica seguimiento)
#   5. unclear: No se puede determinar → REGLA 18 (Solicitar aclaración + Mantener activo)
#   6. out_of_context: Cualquier otro mensaje → Aclarar función del bot
#
# EJEMPLOS DE RECHAZO DETECTADOS (PRIORIDAD 1):
#   - "No me interesa" → Cancela seguimiento + Despedida (generada con IA)
#   - "Ya no estoy interesado" → Cancela seguimiento + Despedida (generada con IA)
#   - "No quiero" → Cancela seguimiento + Despedida (generada con IA)
#   - "Cancelar" → Cancela seguimiento + Despedida (generada con IA)
#   - "Gracias pero no" → Cancela seguimiento + Despedida (generada con IA)
#   - "No me contacten más" → Cancela seguimiento + Despedida (generada con IA)
#   - "Déjame en paz" → Cancela seguimiento + Despedida (generada con IA)
#
# EJEMPLOS DE REAGENDAMIENTO DETECTADOS (PRIORIDAD 2):
#   - "Recuérdame en 20 minutos" → Reagenda +20min + Confirmación (generada con IA)
#   - "Me lo recuerdas en 30 min" → Reagenda +30min + Confirmación (generada con IA)
#   - "Me podrías reagendar para las 14:30" → Reagenda hoy 14:30 + Confirmación (generada con IA)
#   - "Llámame mañana a las 12:00" → Reagenda mañana 12:00 + Confirmación (generada con IA)
#   - "Está muy bien solo que reagéndame en 1 hora" → Reagenda +1h + Confirmación (generada con IA)
#   - "En 2 horas mejor" → Reagenda +2h + Confirmación (generada con IA)
#   - "Mañana por favor" → Reagenda mañana 10am + Confirmación (generada con IA)
#
# EJEMPLOS DE MENSAJES FUERA DE CONTEXTO (PRIORIDAD 3):
#   - "Hola" → Mensaje aclaratorio (generado con IA)
#   - "Cuánto cuesta" → Mensaje aclaratorio (generado con IA)
#   - "Gracias" → Mensaje aclaratorio (generado con IA)
#   - "Buenos días" → Mensaje aclaratorio (generado con IA)
#
# REGLAS DE FILTRADO DE CORTESÍA:
#   REGLA 10: Mensajes vacíos o sin texto son automáticamente descartados
#   REGLA 8 y 9: El bot IGNORA mensajes de cortesía sin contenido relevante
#
# EJEMPLOS DE MENSAJES IGNORADOS (CORTESÍA):
#   - "gracias" → Ignorado (solo cortesía)
#   - "ok" → Ignorado (solo cortesía)
#   - "vale" → Ignorado (solo cortesía)
#   - "buenos días" → Ignorado (solo cortesía)
#   - "saludos" → Ignorado (solo cortesía)
#   - "que tengas buen día" → Ignorado (solo cortesía)
#   - "hasta luego" → Ignorado (solo cortesía)
#   - "perfecto" → Ignorado (solo cortesía)
#   - "entendido" → Ignorado (solo cortesía)
#
# EJEMPLOS DE MENSAJES PROCESADOS (CORTESÍA + CONTENIDO):
#   - "gracias, pero no me interesa" → Procesado (contiene rechazo)
#   - "ok, reagéndame mañana" → Procesado (contiene reagendamiento)
#   - "buenos días, quiero cancelar" → Procesado (contiene rechazo)
#
# GENERACIÓN DE RESPUESTAS CON IA:
#   - Usa OpenAI GPT-4o-mini para generar respuestas personalizadas
#   - Incluye contexto del seguimiento (objetivo, intento, nombre del cliente)
#   - Si falla la IA, usa mensajes por defecto (fallback)
#   - Mensajes más naturales y adaptados a cada situación
#
# CONFIGURACIÓN (Variables de entorno):
#   SENTIMENT_ENABLE_AUTO_REPLY=true (activar respuestas automáticas)
#   SENTIMENT_AI_GENERATED_REPLIES=true (activar generación con IA, default: true)
#
# CÓMO REVERTIR:
#   - Eliminar este archivo
#   - Quitar callback en app/models/message.rb (línea con analyze_for_active_trackings)
# ================================================================================

class ContactTrackingResponseAnalyzerJob < ApplicationJob
  queue_as :default

  # Configuración
  ACCELERATE_HOURS = ENV.fetch('SENTIMENT_ACCELERATE_HOURS', '1').to_i
  AUTO_COMPLETE_ENABLED = ENV.fetch('SENTIMENT_ENABLE_AUTO_COMPLETE', 'true') == 'true'
  AUTO_CANCEL_ENABLED = ENV.fetch('SENTIMENT_ENABLE_AUTO_CANCEL', 'true') == 'true'
  AUTO_REPLY_ENABLED = ENV.fetch('SENTIMENT_ENABLE_AUTO_REPLY', 'true') == 'true'
  AI_GENERATED_REPLIES = ENV.fetch('SENTIMENT_AI_GENERATED_REPLIES', 'true') == 'true'

  # ==============================================================================
  # Método Principal
  # ==============================================================================
  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming? # Solo mensajes del cliente

    Rails.logger.info "[SentimentAnalyzer] 🔍 Analizando mensaje ##{message_id}"

    # REGLA 10: Ignorar mensajes vacíos o sin texto
    if message.content.blank?
      Rails.logger.info "[SentimentAnalyzer] ⏭️ REGLA 10: Mensaje vacío, ignorado"
      return
    end

    # Buscar seguimientos activos PRIMERO para decidar si filtrar cortesía
    active_trackings = find_active_trackings(message)

    # ⚠️⚠️⚠️ REGLA 8 y 9: TEMPORALMENTE DESACTIVADAS PARA PRUEBAS ⚠️⚠️⚠️
    # Para REACTIVAR: Descomenta el bloque entre /* INICIO */ y /* FIN */
    # y comenta la línea "if active_trackings.empty?"

    # /* INICIO - BLOQUE PARA REACTIVAR */
    # REGLA 8 y 9: Ignorar mensajes de cortesía SOLO si NO hay seguimientos activos
    # Si HAY seguimientos activos, palabras como "perfecto", "excelente" pueden indicar interés
    # if active_trackings.empty?
    #   if courtesy_message_only?(message)
    #     Rails.logger.info "[SentimentAnalyzer] ⏭️ REGLA 8/9: Mensaje de cortesía sin seguimientos activos, ignorado"
    #     return
    #   end
    #   Rails.logger.info "[SentimentAnalyzer] ℹ️ No hay seguimientos activos para este contacto"
    #   return
    # end
    #
    # Si hay seguimientos activos, SOLO filtrar cortesías básicas (gracias, hola, adiós)
    # if strict_courtesy_message_only?(message)
    #   Rails.logger.info "[SentimentAnalyzer] ⏭️ REGLA 8/9: Mensaje de cortesía básica, ignorado"
    #   return
    # end
    # /* FIN - BLOQUE PARA REACTIVAR */

    # ⚠️ VALIDACIÓN TEMPORAL: Solo verificar que hay seguimientos activos
    if active_trackings.empty?
      Rails.logger.info "[SentimentAnalyzer] ℹ️ No hay seguimientos activos para este contacto"
      return
    end

    Rails.logger.info "[SentimentAnalyzer] ⚠️ REGLAS 8/9 DESACTIVADAS - Procesando TODO mensaje con seguimiento activo"

    # REGLA 11: DESACTIVADA - Detectar solicitud de demo
    # Esta regla se ejecuta ANTES de verificar seguimientos activos
    # if detect_demo_request?(message)
    #   Rails.logger.info "[SentimentAnalyzer] 🎯 REGLA 11: Solicitud de demo detectada"
    #   handle_demo_request(message)
    #   return # Detener procesamiento, la solicitud de demo tiene prioridad
    # end

    Rails.logger.info "[SentimentAnalyzer] 📋 Encontrados #{active_trackings.count} seguimientos activos"

    # ⭐ MEJORA 1: Analizar con contexto de cada tracking
    active_trackings.each do |tracking|
      Rails.logger.info "[SentimentAnalyzer] 🔍 Analizando para tracking ##{tracking.id}"

      # Analizar sentimiento con contexto del tracking
      sentiment_data = analyze_sentiment_with_context(message, tracking)

      next unless sentiment_data

      Rails.logger.info "[SentimentAnalyzer] 🎯 Sentimiento: #{sentiment_data[:sentiment]} (#{sentiment_data[:confidence]}, método: #{sentiment_data[:method]})"

      # Aplicar decisión
      apply_sentiment_decision(tracking, sentiment_data, message)
    end

  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  private

  # ==============================================================================
  # Búsqueda de Trackings Activos
  # ==============================================================================
  def find_active_trackings(message)
    ContactTracking
      .where(contact_id: message.sender&.id)
      .where(conversation_id: message.conversation_id)
      .active_or_scheduled
  end

  # ==============================================================================
  # REGLA 8, 9, 10: FILTRADO DE MENSAJES DE CORTESÍA
  # ==============================================================================
  # Detecta si el mensaje es SOLO cortesía sin contenido relevante
  def courtesy_message_only?(message)
    return false unless message&.content.present?

    # Limpiar y normalizar el texto
    text = message.content.downcase.strip

    # Eliminar signos de puntuación y emojis para análisis
    clean_text = text.gsub(/[[:punct:]🙏👍✅❤️😊🙂😀👋]/, ' ').gsub(/\s+/, ' ').strip

    # Si después de limpiar está vacío o muy corto (menos de 2 caracteres), es cortesía
    return true if clean_text.length < 2

    # Lista de palabras y frases de cortesía comunes en español
    courtesy_patterns = [
      # Agradecimientos
      /^(muchas\s+)?gracias(\s+(mil|de\s+nuevo|igualmente))?$/,
      /^te\s+agradezco$/,
      /^muy\s+amable$/,

      # Confirmaciones simples
      /^(ok|okay|okey|oki|vale|bien|si|sí|no|dale|listo)$/,
      /^de\s+acuerdo$/,
      /^perfecto$/,
      /^excelente$/,
      /^genial$/,
      /^entendido$/,
      /^claro$/,
      /^por\s+supuesto$/,

      # Saludos
      /^(hola|hey|buenas|ey|que\s+tal)$/,
      /^(buenos|buenas)\s+(días|tardes|noches)$/,
      /^buen\s+día$/,
      /^que\s+tengas?\s+(buen|lind[oa])\s+(día|tarde|noche)$/,

      # Despedidas
      /^(adiós|adios|chao|chau|nos\s+vemos|hasta\s+luego|hasta\s+pronto)$/,
      /^saludos?$/,
      /^cuídate$/,
      /^que\s+estés?\s+bien$/,

      # Expresiones cortas
      /^:?\)$/,  # :)
      /^ya$/,
      /^ahora$/,
      /^luego$/
    ]

    # Verificar si el mensaje limpio coincide EXACTAMENTE con algún patrón de cortesía
    courtesy_patterns.any? { |pattern| clean_text.match?(pattern) }
  end

  # ⭐ NUEVO: Filtro estricto de cortesía (solo cortesías básicas)
  # Se usa cuando HAY seguimientos activos para no bloquear palabras de interés
  def strict_courtesy_message_only?(message)
    return false unless message&.content.present?

    # Limpiar y normalizar el texto
    text = message.content.downcase.strip
    clean_text = text.gsub(/[[:punct:]🙏👍✅❤️😊🙂😀👋]/, ' ').gsub(/\s+/, ' ').strip

    # Si después de limpiar está vacío o muy corto, es cortesía
    return true if clean_text.length < 2

    # SOLO cortesías BÁSICAS que nunca indican interés
    strict_courtesy_patterns = [
      # Agradecimientos simples
      /^(muchas\s+)?gracias(\s+(mil|de\s+nuevo|igualmente))?$/,
      /^te\s+agradezco$/,
      /^muy\s+amable$/,

      # Confirmaciones MUY básicas (ok, vale, listo, bien, sí, no)
      /^(ok|okay|okey|oki|vale|bien|si|sí|no|dale|listo)$/,

      # Saludos
      /^(hola|hey|buenas|ey|que\s+tal)$/,
      /^(buenos|buenas)\s+(días|tardes|noches)$/,
      /^buen\s+día$/,

      # Despedidas
      /^(adiós|adios|chao|chau|nos\s+vemos|hasta\s+luego|hasta\s+pronto)$/,
      /^saludos?$/,
      /^cuídate$/,

      # Expresiones muy cortas
      /^:?\)$/,  # :)
      /^ya$/
    ]

    # NO incluye: "perfecto", "excelente", "genial", "claro", "por supuesto", "entendido"
    # porque estas palabras SÍ pueden indicar interés en contexto de seguimiento

    strict_courtesy_patterns.any? { |pattern| clean_text.match?(pattern) }
  end

  # ==============================================================================
  # REGLA 11: SOLICITUD DE DEMO (KONTROLYA)
  # ==============================================================================
  # Detecta palabras clave relacionadas con solicitudes de demostración
  def detect_demo_request?(message)
    return false unless message&.content.present?

    text = message.content.downcase.strip

    # Palabras clave que indican solicitud de demo
    demo_keywords = [
      /\bdemo\b/,
      /\bdemostraci[oó]n\b/,
      /\bprueba\b/,
      /\bprobar\b/
    ]

    demo_keywords.any? { |pattern| text.match?(pattern) }
  end

  # Maneja la solicitud de demo creando seguimiento automático
  def handle_demo_request(message)
    contact = message.sender
    conversation = message.conversation
    account = message.account

    Rails.logger.info "[REGLA 11] 🎯 Procesando solicitud de demo para contacto ##{contact.id}"

    # 1. Verificar si ya existe un seguimiento de demo activo
    existing_demo = ContactTracking
                      .where(contact_id: contact.id)
                      .where("objective ILIKE ?", "%demo%")
                      .where(status: [:pending, :active, :scheduled])
                      .first

    if existing_demo
      Rails.logger.info "[REGLA 11] ℹ️ Ya existe seguimiento de demo activo (ID: #{existing_demo.id})"
      # Enviar mensaje informativo sin duplicar
      send_demo_message(message, existing: true)
      return
    end

    # 2. Crear nuevo seguimiento de demo programado para 1 hora después
    begin
      # REGLA 23: Usar timezone del inbox para cálculo
      inbox_timezone = conversation.inbox.timezone || 'America/Mexico_City'

      scheduled_time = Time.use_zone(inbox_timezone) do
        1.hour.from_now
      end

      tracking = ContactTracking.create!(
        contact_id: contact.id,
        conversation_id: conversation.id,
        inbox_id: conversation.inbox_id,
        account_id: account.id,
        objective: "Seguimiento de solicitud de demo - Kontrolya",
        scheduled_for: scheduled_time,
        max_attempts: 3,
        retry_interval_value: 1,
        retry_interval_unit: 'days',
        ai_context: "Cliente solicitó una demostración de Kontrolya. Mensaje original: '#{message.content.truncate(100)}'. IMPORTANTE: Al contactar al cliente, SIEMPRE incluir el link de agendamiento: https://kontrolya.com/agenda-una-demostracion/ y mencionar que puede agendar directamente ahí o esperar a que lo contactemos."
      )

      Rails.logger.info "[REGLA 11] ✅ Seguimiento de demo creado (ID: #{tracking.id}) para #{scheduled_time.in_time_zone(inbox_timezone).strftime('%d/%m/%Y %H:%M %Z')}"
      Rails.logger.info "[REGLA 11]    Timezone usado: #{inbox_timezone} → UTC: #{scheduled_time.utc.strftime('%d/%m/%Y %H:%M %Z')}"

      # 3. Enviar mensaje con enlace de agendamiento
      send_demo_message(message, existing: false)

    rescue StandardError => e
      Rails.logger.error "[REGLA 11] ❌ Error creando seguimiento de demo: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end

  # Envía mensaje al cliente con información de la demo
  def send_demo_message(message, existing: false)
    return unless AUTO_REPLY_ENABLED

    contact_name = message.sender&.name || "Cliente"
    first_name = contact_name.split.first

    reply_text = if existing
                   "Hola #{first_name}, veo que ya tienes una solicitud de demo en proceso. " \
                   "Uno de nuestros especialistas se pondrá en contacto contigo pronto. " \
                   "Si prefieres agendar tú mismo una demostración, puedes hacerlo aquí: 👉 https://kontrolya.com/agenda-una-demostracion/"
                 else
                   "¡Hola #{first_name}! Gracias por tu interés en Kontrolya. " \
                   "Me encantaría mostrarte cómo nuestra plataforma puede ayudarte. " \
                   "Agenda una demostración personalizada con nuestro equipo aquí: 👉 https://kontrolya.com/agenda-una-demostracion/ " \
                   "También te daremos seguimiento en breve para asistirte con cualquier duda."
                 end

    Rails.logger.info "[REGLA 11] 💬 Enviando mensaje de demo al cliente"

    send_auto_reply_for_demo(message, reply_text)
  end

  # Envía la respuesta automática al cliente
  def send_auto_reply_for_demo(message, content)
    conversation = message.conversation
    account = conversation.account

    Messages::MessageBuilder.new(
      bot_user(account),
      conversation,
      { content: content, private: false }
    ).perform

    Rails.logger.info "[REGLA 11] ✅ Mensaje enviado exitosamente"
  rescue StandardError => e
    Rails.logger.error "[REGLA 11] ❌ Error enviando mensaje: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  # ==============================================================================
  # ANÁLISIS DE SENTIMIENTO (TODO INTEGRADO AQUÍ)
  # ==============================================================================
  def analyze_sentiment(message)
    text = message.content
    account = message.account

    # REGLA 23: Obtener timezone del inbox
    inbox_timezone = message.conversation.inbox.timezone || 'America/Mexico_City'

    Rails.logger.info "[SentimentAnalyzer] 📝 Analizando texto: '#{text}'"
    Rails.logger.info "[SentimentAnalyzer] 🌍 Timezone: #{inbox_timezone}"

    # Obtener API key
    api_key_data = get_api_key(account)

    # Analizar según método disponible
    result = if api_key_data && api_key_data[:key].present?
               Rails.logger.info "[SentimentAnalyzer] 🤖 Usando OpenAI para análisis"
               analyze_with_openai(text, api_key_data[:key], inbox_timezone)
             else
               Rails.logger.info "[SentimentAnalyzer] 🔤 Usando Keywords para análisis"
               analyze_with_keywords(text, inbox_timezone)
             end

    Rails.logger.info "[SentimentAnalyzer] 🎯 Resultado: #{result[:sentiment]} (confianza: #{result[:confidence]}, método: #{result[:method]})"
    result
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error en análisis: #{e.message}"
    { sentiment: 'neutral', confidence: 0.5, method: 'error' }
  end

  def get_api_key(account)
    # Prioridad 1: Integración de cuenta
    if account
      hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
      if hook && hook.settings['api_key'].present?
        return { key: hook.settings['api_key'], source: 'account_integration' }
      end
    end

    # Prioridad 2: ENV
    if ENV['OPENAI_API_KEY'].present?
      return { key: ENV['OPENAI_API_KEY'], source: 'env' }
    end

    nil
  end

  # ==============================================================================
  # ⭐ MEJORA 1: ANÁLISIS CON CONTEXTO DEL TRACKING
  # ==============================================================================

  # Analiza sentimiento incluyendo contexto del tracking
  def analyze_sentiment_with_context(message, tracking)
    text = message.content
    account = message.account
    inbox_timezone = message.conversation.inbox.timezone || 'America/Mexico_City'

    Rails.logger.info "[SentimentAnalyzer] 📝 Analizando con contexto del tracking ##{tracking.id}"
    Rails.logger.info "[SentimentAnalyzer] 🎯 Objetivo: #{tracking.objective}"

    # ⭐ MEJORA 2: Cache de análisis
    cache_key = generate_cache_key(text, tracking)

    if cached_result = get_cached_analysis(cache_key)
      Rails.logger.info "[SentimentAnalyzer] 📦 Usando análisis cacheado"
      return cached_result
    end

    # Obtener API key
    api_key_data = get_api_key(account)

    # Analizar según método disponible
    result = if api_key_data && api_key_data[:key].present?
               Rails.logger.info "[SentimentAnalyzer] 🤖 Usando OpenAI con contexto enriquecido"
               analyze_with_openai_contextual(text, api_key_data[:key], inbox_timezone, tracking)
             else
               Rails.logger.info "[SentimentAnalyzer] 🔤 Usando Keywords (sin contexto)"
               analyze_with_keywords(text, inbox_timezone)
             end

    # Guardar en cache
    cache_analysis(cache_key, result)

    result
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error en análisis contextual: #{e.message}"
    { sentiment: 'unclear', confidence: 0.5, method: 'error' }
  end

  # Versión mejorada de analyze_with_openai que incluye contexto del tracking
  def analyze_with_openai_contextual(text, api_key, timezone, tracking)
    require 'net/http'
    require 'json'

    # Obtener contenido de plantilla si existe
    template_content = get_template_content(tracking)

    # Obtener historial de mensajes del seguimiento
    message_history = get_tracking_message_history(tracking)

    # Construir contexto del seguimiento
    tracking_context = <<~CONTEXT

      📋 CONTEXTO DEL SEGUIMIENTO:
      - Objetivo: #{tracking.objective}
      - Contexto adicional: #{tracking.ai_context.presence || 'Ninguno'}
      - Intento actual: #{tracking.attempt_count + 1} de #{tracking.max_attempts}
      #{template_content ? "- Plantilla enviada al cliente:\n  \"#{template_content}\"" : "- Sin plantilla (mensaje generado con IA)"}

      #{message_history}

      💡 IMPORTANTE: Usa este contexto Y el historial de mensajes para entender mejor la respuesta del cliente.

      ⚠️ USO DEL HISTORIAL:
      - Si el cliente hace referencia a mensajes anteriores ("como te dije", "ya lo mencioné"), revisa el historial
      - Si la respuesta parece ambigua, usa el historial para entender el contexto completo
      - Si el cliente da una respuesta corta ("sí", "no", "ok"), interpreta según el historial
      - El historial te ayuda a detectar patrones de interés o desinterés
      - Usa el OBJETIVO y el historial para determinar si el mensaje habla del tema del seguimiento

      ⚠️ REGLA DE CUMPLIMIENTO/PROGRESO:
      Si en el OBJETIVO o la PLANTILLA se le pidió al cliente realizar una ACCIÓN específica
      (revisar algo, ver algo, recibir algo, confirmar algo) y el cliente responde indicando
      que YA LO HIZO o está EN PROGRESO, clasifícalo como "interested".

      Ejemplos:
      - Objetivo: "confirmar si revisó la cotización" + Respuesta: "ya la revisé" → interested
      - Plantilla: "¿pudiste ver el video?" + Respuesta: "sí, ya lo vi" → interested
      - Objetivo: "seguimiento de propuesta" + Respuesta: "me llegó la propuesta" → interested
      - Objetivo: "confirmar recepción" + Respuesta: "ya me llegó" → interested
    CONTEXT

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    prompt = <<~PROMPT
      Analiza este mensaje de cliente y determina su intención.

      #{tracking_context}

      INTENCIONES POSIBLES (en orden de prioridad):

      1. rejected: Cliente rechaza claramente el seguimiento o pide que no lo contacten más
         Ejemplos: "no me interesa", "ya no quiero", "cancelar", "no me contacten más"

      2. interested: Cliente muestra INTERÉS, ACEPTA, CUMPLIÓ/PROGRESÓ o hace PREGUNTAS
         ⚠️ MUY IMPORTANTE: Es "interested" si el cliente:
         - Muestra interés directo: "me interesa", "perfecto", "quiero saber más"
         - Hace preguntas: "cuánto cuesta", "cómo funciona", "qué incluye"
         - Indica que CUMPLIÓ la acción pedida: "ya la revisé", "ya lo vi", "ya me llegó"
         - Indica PROGRESO: "estoy revisando", "lo estoy viendo"

         ⚠️ RELACIONA la respuesta con el OBJETIVO y la PLANTILLA del contexto

      3. reschedule: Cliente pide que lo contacten DESPUÉS (REGLA 15, 16, 17, 27)
         Ejemplos de MINUTOS: "en 5min", "5 minutos", "reagendame en 10min", "dentro de 20 min"
         Ejemplos de HORAS: "en 1h", "2 horas", "reagéndame en 1 hora"
         Ejemplos de HORA ESPECÍFICA: "llámame a las 14:30", "a las 3", "hoy a las 5pm"
         Ejemplos de DÍAS: "mañana", "en 2 días", "el martes"

         ⚠️ EXTRACCIÓN DE TIEMPO - REGLAS CRÍTICAS:

         A) TIEMPO RELATIVO (detecta TODAS estas variaciones):
            - MINUTOS: "5min", "5 min", "5 minutos", "cinco minutos" → relative_minutes: 5
            - HORAS: "1h", "1 hora", "2 horas", "una hora" → relative_hours: 1 o 2
            - DÍAS: "mañana", "1 día", "2 días" → relative_days: 1 o 2

         B) REGLA 16 - HORA ESPECÍFICA (sin fecha):
            - Si dice un número sin AM/PM (ej: "a las 3", "a las 5"), convertir a PM (formato 24h)
              * "a las 3" → specific_time: "15:00" (3 PM)
              * "a las 5" → specific_time: "17:00" (5 PM)
              * "a las 11" → specific_time: "23:00" (11 PM)
            - Si especifica AM o PM, respetar exactamente:
              * "a las 3 PM" → specific_time: "15:00"
              * "a las 10 AM" → specific_time: "10:00"
            - Formato SIEMPRE en 24 horas (HH:MM)

         C) PRIORIDAD: relative_minutes/hours/days tiene MÁXIMA PRIORIDAD sobre specific_time

      4. neutral: Cliente menciona EXPLÍCITAMENTE que AÚN NO completó la acción del OBJETIVO, pero SIN rechazar
         ⚠️ CRÍTICO: Debe hablar DIRECTAMENTE sobre el OBJETIVO (revisar, ver, recibir, etc.)

         Ejemplos CORRECTOS de neutral:
         - "aún no la reviso", "todavía no la he visto", "no he tenido tiempo de revisarla"
         - "la voy a revisar más tarde", "dame unos días para verla", "estoy ocupado, no he podido revisarla"
         - "no he podido verla", "no me ha dado tiempo de revisarla", "pendiente de revisar"

         Ejemplos INCORRECTOS (NO son neutral):
         - "¿qué hora es?" → out_of_context (NO habla del objetivo)
         - "¿quién descubrió américa?" → out_of_context (NO habla del objetivo)
         - "hola" → out_of_context (NO habla del objetivo)

         ⚠️ DIFERENCIA CLAVE:
         - "aún no la reviso" → neutral (habla sobre NO completar la ACCIÓN del objetivo)
         - "¿qué hora es?" → out_of_context (NO habla del objetivo para nada)
         - "no me interesa" → rejected (rechazo explícito)

      5. unclear: No se puede determinar claramente la intención
         Ejemplos: mensajes ambiguos, incompletos o confusos relacionados al objetivo

      6. out_of_context: Mensajes que NO están relacionados con el objetivo del seguimiento
         ⚠️ INCLUYE: saludos, agradecimientos, preguntas aleatorias, temas no relacionados

         Ejemplos:
         - Saludos: "hola", "buenos días", "qué tal"
         - Agradecimientos: "gracias", "ok", "de acuerdo"
         - Preguntas aleatorias: "¿qué hora es?", "¿quién descubrió américa?", "¿cómo está el clima?"
         - Temas no relacionados: cualquier mensaje que NO mencione el objetivo

      7. question: Cliente hace una PREGUNTA específica sobre los DETALLES de su seguimiento
         ⚠️ SOLO aplica si la pregunta está RELACIONADA con el objetivo/contexto del seguimiento

         Ejemplos:
         - "¿A qué hora es mi cita?" → question (pregunta sobre detalles del servicio)
         - "¿Qué día viene el técnico?" → question (pregunta sobre fecha/hora)
         - "¿Cuánto costará?" → question (pregunta sobre precio del servicio mencionado)
         - "¿Qué incluye el servicio?" → question (pregunta sobre detalles)
         - "¿Dónde es la instalación?" → question (pregunta sobre ubicación)

         ⚠️ DIFERENCIA con "interested":
         - "cuánto cuesta" (sin ?) + tono de interés → interested
         - "¿cuánto cuesta?" (pregunta directa buscando información) → question

         ⚠️ DIFERENCIA con "out_of_context":
         - "¿qué hora es?" (pregunta NO relacionada al objetivo) → out_of_context
         - "¿a qué hora es mi cita?" (pregunta SÍ relacionada al objetivo) → question

      Mensaje del cliente: "#{text}"
      Hora actual (#{timezone}): #{Time.current.in_time_zone(timezone).strftime('%Y-%m-%d %H:%M %Z')}

      REGLAS CRÍTICAS:
      1. Si contiene "interesa", "quiero", "cuánto", "perfecto" → SIEMPRE es "interested"
      2. ⚠️ Si el cliente indica CUMPLIMIENTO ("ya lo hice", "ya la vi", "me llegó") → SIEMPRE es "interested"
      3. ⚠️ RELACIONA la respuesta con el OBJETIVO/PLANTILLA del contexto para detectar cumplimiento
      4. ⚠️ NEUTRAL vs OUT_OF_CONTEXT - DIFERENCIA CRÍTICA:
         - neutral: Cliente HABLA sobre el objetivo pero dice que NO lo completó aún ("aún no la reviso")
         - out_of_context: Cliente NO habla del objetivo para nada ("¿qué hora es?", "hola", preguntas aleatorias)
      5. Si pide reagendar con tiempo específico → es "reschedule"
      6. Si rechaza claramente → es "rejected"
      7. "out_of_context" incluye: saludos, agradecimientos Y preguntas/temas NO relacionados con el objetivo
      8. En duda entre "interested" y "out_of_context" → elige "interested"
      9. En duda entre "neutral" y "out_of_context" → pregúntate: ¿habla del objetivo? SÍ=neutral, NO=out_of_context

      Si es "rejected", responde:
      { "intent": "rejected", "confidence": 0.9 }

      Si es "interested", responde:
      { "intent": "interested", "confidence": 0.9 }

      Si es "reschedule", extrae CUÁNDO quiere ser contactado (incluye SOLO los campos aplicables):

      Ejemplos de formato de respuesta:

      Para "reagendame en 5min" o "5 minutos":
      { "intent": "reschedule", "confidence": 0.9, "when": { "relative_minutes": 5, "natural": "en 5 minutos" } }

      Para "en 2 horas":
      { "intent": "reschedule", "confidence": 0.9, "when": { "relative_hours": 2, "natural": "en 2 horas" } }

      Para "a las 14:30" o "a las 2:30pm":
      { "intent": "reschedule", "confidence": 0.9, "when": { "specific_time": "14:30", "natural": "a las 14:30" } }

      Para "mañana":
      { "intent": "reschedule", "confidence": 0.9, "when": { "relative_days": 1, "natural": "mañana" } }

      Para "mañana a las 3pm":
      { "intent": "reschedule", "confidence": 0.9, "when": { "relative_days": 1, "specific_time": "15:00", "natural": "mañana a las 3pm" } }

      ⚠️ NO incluyas campos vacíos o null - solo los que apliquen

      Si es "neutral", responde:
      { "intent": "neutral", "confidence": 0.8 }

      Si es "unclear", responde:
      { "intent": "unclear", "confidence": 0.5 }

      Si es "out_of_context", responde:
      { "intent": "out_of_context", "confidence": 0.8 }

      Si es "question", responde:
      { "intent": "question", "confidence": 0.8 }

      Responde SOLO con JSON válido.
    PROMPT

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 300,
      response_format: { type: 'json_object' }
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    ai_response = JSON.parse(response_body.dig('choices', 0, 'message', 'content') || '{}')

    Rails.logger.info "[SentimentAnalyzer] 🤖 Respuesta OpenAI: #{ai_response.inspect}"

    intent = ai_response['intent'] || 'unclear'
    result = {
      sentiment: intent,
      confidence: ai_response['confidence'] || 0.7,
      method: 'openai_contextual',
      raw_response: ai_response
    }

    # ⭐ FIX: Mapear 'when' a :reschedule_data con keys como símbolos
    if intent == 'reschedule' && ai_response['when'].is_a?(Hash)
      result[:reschedule_data] = ai_response['when'].transform_keys(&:to_sym)
    end

    result
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error en OpenAI contextual: #{e.message}"
    { sentiment: 'unclear', confidence: 0.5, method: 'error' }
  end

  # Obtiene el contenido de la plantilla WhatsApp configurada
  def get_template_content(tracking)
    return nil unless tracking.use_template_for_current_attempt?

    template_name = tracking.current_template
    return nil unless template_name

    channel = tracking.inbox.channel
    return nil unless channel.respond_to?(:message_templates)
    return nil unless channel.message_templates.is_a?(Array)

    template = channel.message_templates.find { |t| t['name'] == template_name }
    return nil unless template

    body_component = template['components']&.find { |c| c['type'] == 'BODY' }
    body_text = body_component&.dig('text')

    if body_text.present?
      Rails.logger.info "[SentimentAnalyzer] 📄 Plantilla encontrada: #{body_text.truncate(100)}"
      body_text.truncate(300)
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error obteniendo plantilla: #{e.message}"
    nil
  end

  # Obtiene el historial de mensajes del seguimiento para contexto
  def get_tracking_message_history(tracking)
    return "" unless tracking.conversation_id.present?

    begin
      # Obtener mensajes POSTERIORES a la creación del tracking
      messages = Message.where(conversation_id: tracking.conversation_id)
                        .where("created_at > ?", tracking.created_at)
                        .where(message_type: [0, 1]) # 0=incoming, 1=outgoing
                        .order(created_at: :asc)
                        .limit(20) # Limitar a últimos 20 mensajes para no saturar el prompt

      return "" if messages.empty?

      # Formatear el historial
      history_text = "💬 HISTORIAL DE MENSAJES DEL SEGUIMIENTO:\n"

      messages.each do |msg|
        sender_label = msg.incoming? ? "Cliente" : "Bot"
        timestamp = msg.created_at.strftime("%d/%m %H:%M")
        content = msg.content.to_s.truncate(200)

        history_text += "      [#{timestamp}] #{sender_label}: #{content}\n"
      end

      history_text += "\n      ⚠️ Usa este historial para entender el contexto completo de la conversación.\n"

      Rails.logger.info "[SentimentAnalyzer] 📜 Historial incluido: #{messages.count} mensajes"
      history_text
    rescue StandardError => e
      Rails.logger.error "[SentimentAnalyzer] ❌ Error obteniendo historial: #{e.message}"
      ""
    end
  end

  # ==============================================================================
  # ⭐ MEJORA 2: SISTEMA DE CACHE
  # ==============================================================================

  # Cache en clase para persistir entre jobs
  @@analysis_cache = {}
  @@cache_ttl = 1.hour

  def generate_cache_key(text, tracking)
    content_hash = Digest::MD5.hexdigest(text.downcase.strip)
    "sentiment_#{tracking.objective.parameterize}_#{content_hash}"
  end

  def get_cached_analysis(cache_key)
    cached = @@analysis_cache[cache_key]
    return nil unless cached

    if cached[:timestamp] > @@cache_ttl.ago
      cached[:result]
    else
      @@analysis_cache.delete(cache_key)
      nil
    end
  end

  def cache_analysis(cache_key, result)
    @@analysis_cache[cache_key] = {
      result: result,
      timestamp: Time.current
    }

    # Limpiar cache antiguo si tiene más de 100 entradas
    if @@analysis_cache.size > 100
      @@analysis_cache.select! { |_k, v| v[:timestamp] > @@cache_ttl.ago }
    end
  end

  def analyze_with_openai(text, api_key, timezone = 'America/Mexico_City')
    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    prompt = <<~PROMPT
      Analiza este mensaje de cliente y determina su intención.

      CONTEXTO:
      Este es un bot de seguimiento que puede reagendar contactos o cancelar el seguimiento.
      El cliente recibió un mensaje de seguimiento y está respondiendo.

      INTENCIONES POSIBLES (en orden de prioridad):

      1. rejected: Cliente rechaza claramente el seguimiento o pide que no lo contacten más (REGLA 12, 14)
         Ejemplos: "no me interesa", "ya no quiero", "cancelar", "no me contacten más",
                   "gracias pero no", "déjame en paz", "no estoy interesado", "ya no", "detener"

      2. interested: Cliente muestra INTERÉS, ACEPTA o hace PREGUNTAS sobre el producto/servicio
         ⚠️ MUY IMPORTANTE: Cualquier palabra que indique aceptación, interés o pregunta ES "interested"

         Ejemplos AFIRMATIVOS (SIEMPRE son "interested"):
         - "me interesa" ✅
         - "sí me interesa" ✅
         - "si me interesa" ✅ (sin acento también)
         - "perfecto" ✅
         - "excelente" ✅
         - "me gusta" ✅
         - "claro que sí" ✅
         - "por supuesto" ✅
         - "sí quiero" ✅
         - "estoy interesado" ✅

         Ejemplos de PREGUNTAS (SIEMPRE son "interested"):
         - "cuéntame más" ✅
         - "qué incluye" ✅
         - "cuánto cuesta" ✅
         - "quiero saber más" ✅
         - "tengo preguntas" ✅
         - "dime más información" ✅
         - "envíame información" ✅

      3. reschedule: Cliente pide que lo contacten DESPUÉS (REGLA 15, 16, 17, 27)
         Ejemplos: "recuérdame en 20min", "llámame a las 14:30", "mañana mejor",
                   "me lo recuerdas en 30 min", "me podrías reagendar para las 12:00",
                   "está muy bien solo que reagéndame en 1 hora", "en 2 días", "hoy a las 3"

         REGLA 16 - INTERPRETACIÓN DE HORAS (MUY IMPORTANTE):
         - Si dice un número sin AM/PM (ej: "a las 3", "a las 5"), convertir a PM (formato 24h)
           * "a las 3" → specific_time: "15:00" (3 PM)
           * "a las 5" → specific_time: "17:00" (5 PM)
           * "a las 11" → specific_time: "23:00" (11 PM)
         - Si especifica AM o PM, respetar exactamente:
           * "a las 3 PM" → specific_time: "15:00"
           * "a las 10 AM" → specific_time: "10:00"
         - Formato SIEMPRE en 24 horas (HH:MM)

      4. unclear: No se puede determinar claramente la intención (REGLA 18)
         Ejemplos: mensajes ambiguos, incompletos o confusos

      5. out_of_context: SOLO saludos básicos o agradecimientos simples SIN ningún interés
         Ejemplos: "hola", "gracias", "buenos días", "ok", "vale"
         ⚠️ NO uses "out_of_context" si hay CUALQUIER señal de interés o pregunta

      Mensaje: "#{text}"
      Hora actual (#{timezone}): #{Time.current.in_time_zone(timezone).strftime('%Y-%m-%d %H:%M %Z')}

      REGLAS CRÍTICAS DE CLASIFICACIÓN:
      1. Si contiene "interesa", "quiero", "cuánto", "qué incluye", "información",
         "perfecto", "excelente", "me gusta", "sí" → SIEMPRE es "interested"
      2. Si pide reagendar con tiempo específico → es "reschedule"
      3. Si rechaza claramente → es "rejected"
      4. Solo usa "out_of_context" para saludos/agradecimientos básicos SIN NINGÚN interés
      5. En caso de duda entre "interested" y "out_of_context" → elige "interested"

      Si es "rejected", responde:
      { "intent": "rejected" }

      Si es "interested", responde:
      { "intent": "interested" }

      Si es "reschedule", extrae CUÁNDO quiere ser contactado (REGLA 16, 27):
      {
        "intent": "reschedule",
        "when": {
          "relative_minutes": 20,
          "relative_hours": 2,
          "relative_days": 1,
          "specific_time": "14:30",
          "specific_date": "2025-12-23",
          "natural": "en 20 minutos"
        }
      }

      Si es "unclear", responde:
      { "intent": "unclear" }

      Si es "out_of_context", responde:
      { "intent": "out_of_context" }
    PROMPT

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
      max_tokens: 200,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    ai_response = JSON.parse(response_body.dig('choices', 0, 'message', 'content') || '{}')
    intent = ai_response['intent']&.strip&.downcase

    if %w[reschedule rejected interested unclear out_of_context question].include?(intent)
      result = {
        sentiment: intent,
        confidence: 0.95,
        method: 'openai',
        analyzed_at: Time.current
      }
      result[:reschedule_data] = ai_response['when'] if intent == 'reschedule'
      result
    else
      analyze_with_keywords(text, timezone)
    end
  rescue StandardError => e
    Rails.logger.warn "[SentimentAnalyzer] OpenAI falló: #{e.message}"
    analyze_with_keywords(text, timezone)
  end

  def analyze_with_keywords(text, timezone = 'America/Mexico_City')
    text_lower = text.downcase

    # ⭐ PRIORIDAD 1: Detectar rechazo (MÁS IMPORTANTE)
    rejected_patterns = [
      /\bno\s+me\s+interesa/i,
      /\bya\s+no\s+(me\s+)?interesa/i,
      /\bno\s+estoy\s+interesado/i,
      /\bya\s+no\s+estoy\s+interesado/i,
      /\bno\s+quiero/i,
      /\bya\s+no\s+quiero/i,
      /\bno\s+deseo/i,
      /\bno\s+necesito/i,
      /\bcancelar/i,
      /\bcancela(r)?\s+(todo|esto|el\s+seguimiento)/i,
      /\bno\s+gracias/i,
      /\bgracias\s+pero\s+no/i,
      /\bno\s+me\s+contacten/i,
      /\bno\s+me\s+llamen/i,
      /\bno\s+me\s+escriban/i,
      /\bdéjame\s+en\s+paz/i,
      /\bdejar\s+de\s+(contactar|molestar|escribir)/i,
      /\bretir(ar|en|arse)\s+(de|del|me)/i,
      /\bb[aá]j(a|en)(r)?(me)?\s+(de|del)\s+(la\s+)?lista/i
    ]

    matched_reject = rejected_patterns.find { |pattern| text =~ pattern }

    if matched_reject
      Rails.logger.info "[SentimentAnalyzer] 🚫 Patrón de rechazo detectado: #{matched_reject.inspect}"
      return {
        sentiment: 'rejected',
        confidence: 0.9,
        method: 'keywords',
        analyzed_at: Time.current
      }
    end

    # ⭐ PRIORIDAD 2: Detectar reagendamiento con patrones mejorados
    reschedule_patterns = [
      # Patrones con verbos "recuerda/recordar" + tiempo
      /\b(me\s+)?(lo\s+)?(te\s+)?(puedes?|podr[ií]as?|favor\s+)?recuérd[ae]me\b/i,
      /\b(me\s+)?(lo\s+)?(te\s+)?(puedes?|podr[ií]as?|favor\s+)?recuerdame\b/i,
      /\brecord[aá]r(me)?\s+(en|a|para|m[aá]s|despu[eé]s|luego|ma[ñn]ana)/i,

      # Patrones con verbo "reagendar"
      /\b(me\s+)?(lo\s+)?(te\s+)?(puedes?|podr[ií]as?|favor\s+)?reagend[ae]/i,
      /\breagenda(r)?(me)?\b/i,

      # Patrones con verbos de comunicación + tiempo
      /\b(me\s+)?(lo\s+)?(puedes?|podr[ií]as?|favor\s+)?ll[aá]mame\s+(en|a|para|despu[eé]s|luego|ma[ñn]ana|tarde)/i,
      /\b(me\s+)?(lo\s+)?(puedes?|podr[ií]as?|favor\s+)?cont[aá]ctame\s+(en|a|para|despu[eé]s|luego|ma[ñn]ana|tarde)/i,
      /\b(me\s+)?(lo\s+)?(puedes?|podr[ií]as?|favor\s+)?escr[ií]beme\s+(en|a|para|despu[eé]s|luego|ma[ñn]ana|tarde)/i,
      /\b(me\s+)?(lo\s+)?(puedes?|podr[ií]as?|favor\s+)?h[aá]blame\s+(en|a|para|despu[eé]s|luego|ma[ñn]ana|tarde)/i,

      # Patrones de tiempo específico (muy confiables)
      /\ben\s+\d+\s*(minutos?|mins?|min\b)/i,
      /\ben\s+\d+\s*(horas?|hrs?|hr\b)/i,
      /\ben\s+\d+\s*(d[ií]as?|dia\b)/i,
      /\ba\s*las?\s*\d{1,2}:\d{2}/i,
      /\ba\s*las?\s*\d{1,2}\s*(am|pm|de\s+la\s+(ma[ñn]ana|tarde|noche))/i,

      # Patrones temporales en contexto
      /\b(pero\s+|solo\s+(que\s+)?)?ma[ñn]ana\s+(mejor|por\s+favor|a\s*las?|en)/i,
      /\bm[aá]s\s+tarde\s+(por\s+favor|mejor|a\s*las?)?/i,
      /\bdespu[eé]s\s+(por\s+favor|mejor|te\s+contacto)?/i,
      /\bluego\s+(te\s+)?(contacto|hablamos|llamo)/i,

      # Patrones con contexto mixto (afirmativo + reagendamiento)
      /\b(bien|bueno|perfecto|excelente|genial|interesante|me\s+gusta)\s+(pero|solo\s+que|aunque)\s+(me\s+)?(lo\s+)?(puedes?|podr[ií]as?)?\s*(recuerd|reagend|llam|contact|escrib|habl)/i,
      /\b(s[ií]|ok|vale|est[aá]\s+bien)\s+(pero|solo\s+que|aunque)\s+(en|a\s*las?|ma[ñn]ana|despu[eé]s|luego|tarde)/i
    ]

    matched_pattern = reschedule_patterns.find { |pattern| text =~ pattern }

    if matched_pattern
      Rails.logger.info "[SentimentAnalyzer] 🔍 Patrón de reschedule detectado: #{matched_pattern.inspect}"
      reschedule_data = extract_time_from_text(text, timezone)
      Rails.logger.info "[SentimentAnalyzer] 🔍 Datos extraídos: #{reschedule_data.inspect}"

      return {
        sentiment: 'reschedule',
        reschedule_data: reschedule_data,
        confidence: 0.85,
        method: 'keywords',
        analyzed_at: Time.current
      }
    end

    # ⭐ PRIORIDAD 3: Detectar INTERÉS claro (REGLA 13)
    interested_patterns = [
      # Expresiones directas de interés
      /\b(s[ií]|si)\s+(me\s+)?interesa/i,
      /\bestoy\s+interesad[oa]/i,
      /\bme\s+interesa/i,
      /\bquiero\s+saber\s+m[aá]s/i,
      /\bcu[eé]ntame\s+m[aá]s/i,
      /\bdime\s+m[aá]s/i,
      /\bqu[eé]\s+incluye/i,
      /\bcu[aá]nto\s+cuesta/i,
      /\bcu[aá]l\s+es\s+el\s+precio/i,
      /\bquisiera\s+(informaci[oó]n|saber|conocer)/i,
      /\bme\s+gustar[ií]a\s+(saber|conocer|informaci[oó]n)/i,
      /\btengo\s+(preguntas|dudas|inter[eé]s)/i,
      /\bpuedes\s+darme\s+(m[aá]s\s+)?informaci[oó]n/i,
      /\benvi[aá]me\s+(informaci[oó]n|detalles|datos)/i,
      /\bmanda(me)?\s+(informaci[oó]n|detalles|datos)/i,
      /\bm[aá]s\s+informaci[oó]n\s+por\s+favor/i,
      /\bs[ií]\s+quiero/i,
      /\bme\s+gustar[ií]a\s+adquirir/i,
      /\bme\s+gustar[ií]a\s+comprar/i,
      /\bcl[aá]ro\s+(que\s+)?s[ií]/i,
      /\bpor\s+supuesto/i,
      /\bexcelente/i,
      /\bperfecto/i,
      /\bme\s+gusta/i,
      /\bsuena\s+bien/i,
      /\bsuena\s+interesante/i
    ]

    matched_interest = interested_patterns.find { |pattern| text =~ pattern }

    if matched_interest
      Rails.logger.info "[SentimentAnalyzer] ✅ Patrón de INTERÉS detectado: #{matched_interest.inspect}"
      return {
        sentiment: 'interested',
        confidence: 0.9,
        method: 'keywords',
        analyzed_at: Time.current
      }
    end

    # Si llegamos aquí, NO es reschedule ni interested → mensaje fuera de contexto
    Rails.logger.info "[SentimentAnalyzer] 🚫 Mensaje fuera de contexto (no es solicitud de reagendamiento ni muestra interés claro)"

    {
      sentiment: 'out_of_context',
      confidence: 0.75,
      method: 'keywords',
      analyzed_at: Time.current
    }
  end

  # ==============================================================================
  # EXTRACCIÓN DE TIEMPO/FECHA DEL TEXTO
  # ==============================================================================

  def extract_time_from_text(text, timezone = 'America/Mexico_City')
    result = {}

    # REGLA 23: Usar timezone del inbox para cálculos
    Time.use_zone(timezone) do
      # Patrón: "en X minutos" (incluyendo variantes como "min", "mins")
      if text =~ /en\s+(\d+)\s*(minutos?|mins?)/i
        result[:relative_minutes] = $1.to_i
        result[:natural] = "en #{$1} minutos"
        Rails.logger.info "[SentimentAnalyzer] ⏱️  Detectado: #{$1} minutos"
      end

      # Patrón: "en X horas" (incluyendo variantes como "hr", "hrs")
      if text =~ /en\s+(\d+)\s*(horas?|hrs?)/i
        result[:relative_minutes] = $1.to_i * 60
        result[:natural] = "en #{$1} horas"
        Rails.logger.info "[SentimentAnalyzer] ⏱️  Detectado: #{$1} horas"
      end

      # Patrón: "en X días"
      if text =~ /en\s+(\d+)\s*(días?|dias?)/i
        result[:relative_minutes] = $1.to_i * 1440
        result[:natural] = "en #{$1} días"
        Rails.logger.info "[SentimentAnalyzer] ⏱️  Detectado: #{$1} días"
      end

      # Patrón: "a las 14:30" o "a las 2:30 pm"
      if text =~ /a\s*las?\s*(\d{1,2}):(\d{2})/i
        result[:specific_time] = "#{$1}:#{$2}"
        result[:natural] = "a las #{$1}:#{$2}"
        Rails.logger.info "[SentimentAnalyzer] 🕐 Detectado: a las #{$1}:#{$2}"
      end

      # Patrón: "mañana" - REGLA 23: Calcular desde timezone local
      if text =~ /mañana/i
        result[:specific_date] = 1.day.from_now.strftime('%Y-%m-%d')
        result[:natural] = result[:natural] ? "mañana #{result[:natural]}" : "mañana"
        Rails.logger.info "[SentimentAnalyzer] 📅 Detectado: mañana (#{result[:specific_date]} en #{timezone})"
      end

      # Patrón: "más tarde" o "después" (solo si no detectó nada más)
      if text =~ /(más\s+)?tarde|después|luego/i && result.empty?
        result[:relative_minutes] = 120 # Default: 2 horas
        result[:natural] = "más tarde (en 2 horas)"
        Rails.logger.info "[SentimentAnalyzer] ⏱️  Detectado: más tarde (default 2h)"
      end
    end

    Rails.logger.info "[SentimentAnalyzer] 📊 Resultado extracción: #{result.inspect}"
    result
  end

  def calculate_reschedule_datetime(reschedule_data, timezone = 'America/Mexico_City')
    Rails.logger.info "[SentimentAnalyzer] 🧮 Calculando fecha/hora con: #{reschedule_data.inspect}"
    Rails.logger.info "[SentimentAnalyzer] 🌍 Zona horaria: #{timezone}"

    # REGLA 23: Usar la zona horaria del inbox para todos los cálculos
    Time.use_zone(timezone) do
      now = Time.current

      # Prioridad 1: Tiempo relativo (en X minutos, horas, días)
      if reschedule_data[:relative_minutes]
        new_time = reschedule_data[:relative_minutes].minutes.from_now
        Rails.logger.info "[SentimentAnalyzer] ✅ Usando tiempo relativo: +#{reschedule_data[:relative_minutes]} min → #{new_time.strftime('%d/%m/%Y %H:%M %Z')}"
        return new_time
      end

      if reschedule_data[:relative_hours]
        new_time = reschedule_data[:relative_hours].hours.from_now
        Rails.logger.info "[SentimentAnalyzer] ✅ Usando tiempo relativo: +#{reschedule_data[:relative_hours]}h → #{new_time.strftime('%d/%m/%Y %H:%M %Z')}"
        return new_time
      end

      if reschedule_data[:relative_days]
        new_time = reschedule_data[:relative_days].days.from_now.change(hour: 10, min: 0, sec: 0)
        Rails.logger.info "[SentimentAnalyzer] ✅ Usando tiempo relativo: +#{reschedule_data[:relative_days]} días a las 10:00 AM → #{new_time.strftime('%d/%m/%Y %H:%M %Z')}"
        return new_time
      end

      # REGLA 27: Prioridad 2: Hora específica + fecha (PRIORIDAD ABSOLUTA)
      if reschedule_data[:specific_time]
        hour, minute = reschedule_data[:specific_time].split(':').map(&:to_i)

        # REGLA 16: Si la IA no especificó AM/PM, debería haber convertido a formato 24h con PM por defecto
        # Aquí solo aplicamos la hora que la IA ya procesó

        # Si hay fecha específica, usar esa (REGLA 27)
        if reschedule_data[:specific_date]
          base_date = Time.zone.parse(reschedule_data[:specific_date])
          target = base_date.change(hour: hour, min: minute, sec: 0)
          Rails.logger.info "[SentimentAnalyzer] 🎯 REGLA 27: Fecha+hora exacta → #{target.strftime('%d/%m/%Y %H:%M %Z')}"
        else
          # REGLA 17: Si no hay fecha, usar hoy (conservar día)
          target = now.change(hour: hour, min: minute, sec: 0)
          # Si ya pasó la hora hoy, programar para mañana
          if target < now
            target = target + 1.day
            Rails.logger.info "[SentimentAnalyzer] ⏩ Hora ya pasó, moviendo a mañana (REGLA 17)"
          end
          Rails.logger.info "[SentimentAnalyzer] 🎯 REGLA 17: Solo hora → #{target.strftime('%d/%m/%Y %H:%M %Z')}"
        end

        return target
      end

      # REGLA 16: Prioridad 3: Solo fecha específica (a las 10:00 AM por defecto)
      if reschedule_data[:specific_date]
        new_time = Time.zone.parse("#{reschedule_data[:specific_date]} 10:00:00")
        Rails.logger.info "[SentimentAnalyzer] ✅ REGLA 16: Fecha sin hora → 10:00 AM → #{new_time.strftime('%d/%m/%Y %H:%M %Z')}"
        return new_time
      end

      # Fallback: 1 hora desde ahora
      new_time = 1.hour.from_now
      Rails.logger.warn "[SentimentAnalyzer] ⚠️ Sin datos específicos, usando fallback: +1h → #{new_time.strftime('%d/%m/%Y %H:%M %Z')}"
      new_time
    end
  end

  # ==============================================================================
  # APLICAR DECISIÓN SEGÚN SENTIMIENTO
  # ==============================================================================
  def apply_sentiment_decision(tracking, sentiment_data, message)
    sentiment = sentiment_data[:sentiment]
    confidence = sentiment_data[:confidence]

    # Guardar análisis
    save_sentiment_analysis(tracking, sentiment_data, message)

    # Aplicar acción según sentimiento
    case sentiment
    when 'rejected'
      handle_rejected(tracking, message, confidence)
    when 'interested'
      handle_interested(tracking, message, confidence)
    when 'neutral'
      handle_neutral(tracking, message, confidence)
    when 'reschedule'
      handle_reschedule(tracking, message, sentiment_data)
    when 'unclear'
      handle_unclear(tracking, message, confidence)
    when 'out_of_context'
      handle_out_of_context(tracking, message, confidence)
    when 'question'
      handle_question(tracking, message, confidence)
    else
      Rails.logger.warn "[SentimentAnalyzer] ⚠️ Sentimiento desconocido: #{sentiment}"
    end
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error aplicando decisión: #{e.message}"
  end

  # ==============================================================================
  # HANDLERS POR SENTIMIENTO
  # ==============================================================================

  def handle_out_of_context(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] 🚫 OUT_OF_CONTEXT → Aclarando función del bot"

    # Generar mensaje contextualizado con IA o usar mensaje por defecto
    reply_text = generate_contextualized_reply(tracking, message, :out_of_context)

    # ⭐ Agregar marcador #FC (Fuera de Contexto)
    reply_text = "#{reply_text} #FC"

    # Enviar respuesta
    send_auto_reply(tracking, message, reply_text)

    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n💬 Cliente envió mensaje fuera de contexto: \"#{message.content.truncate(100)}\""
    )
  end

  # ⭐ NUEVO: Manejar preguntas del cliente sobre el seguimiento
  def handle_question(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] ❓ QUESTION → Respondiendo pregunta del cliente sobre el seguimiento"

    # Generar respuesta usando el prompt complementario
    reply_text = generate_contextualized_reply(tracking, message, :question)

    # ⭐ Agregar marcador #IF (Información de Seguimiento)
    reply_text = "#{reply_text} #IF"

    # Enviar respuesta
    send_auto_reply(tracking, message, reply_text)

    # Registrar en el contexto (NO modifica el estado del seguimiento)
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n❓ Cliente preguntó: \"#{message.content.truncate(100)}\""
    )

    Rails.logger.info "[SentimentAnalyzer] ✅ Pregunta respondida (seguimiento sin cambios)"
  end

  def handle_rejected(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] ❌ REJECTED (REGLA 12, 14) → Cancelando seguimiento por rechazo del cliente"

    # REGLA 14: Enviar mensaje de despedida cortés
    reply_text = generate_contextualized_reply(tracking, message, :rejected)

    # ⭐ Agregar marcador #IN (Intención Negativa)
    reply_text = "#{reply_text} #IN"

    send_auto_reply(tracking, message, reply_text)

    # ⭐ Desactivar modo reintento automático (el cliente rechazó)
    tracking.disable_auto_retry_mode!

    # REGLA 14: Marcar seguimiento como cancelled
    tracking.update!(
      status: 'cancelled',
      last_error: 'Cancelado: Cliente rechazó seguimiento',
      ai_context: "#{tracking.ai_context}\n\n❌ CANCELADO: Cliente rechazó seguimiento explícitamente\nMensaje: \"#{message.content.truncate(100)}\""
    )

    # REGLA 12: Crear mensaje privado notificando al agente
    create_private_note(tracking, message, "Cliente rechazó el seguimiento: \"#{message.content.truncate(100)}\"")

    Rails.logger.info "[SentimentAnalyzer] ✅ Seguimiento cancelado exitosamente (REGLA 14)"
  end

  def handle_interested(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] ✅ INTERESTED (REGLA 13) → Cliente muestra interés"

    # ⭐ Desactivar modo reintento automático (el cliente mostró interés)
    tracking.disable_auto_retry_mode!

    # Generar respuesta de confirmación
    reply_text = generate_contextualized_reply(tracking, message, :interested)

    # ⭐ Agregar marcador #IP (Intención Positiva)
    reply_text = "#{reply_text} #IP"

    # Enviar respuesta automática
    send_auto_reply(tracking, message, reply_text)

    # ⭐ REGLA 13 MODIFICADA: Pausar seguimiento (en lugar de completar)
    # Esto permite que un agente humano retome la conversación
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏸️ PAUSADO: Cliente mostró interés positivo (#IP)\nMensaje: \"#{message.content.truncate(100)}\"\nRequiere atención humana."
    )
    tracking.pause!

    # REGLA 13: Notificar al administrador para intervención humana
    notify_admin_interested(tracking, message)

    # REGLA 13: Crear mensaje privado
    create_private_note(tracking, message, "⏸️ Seguimiento PAUSADO - ¡Cliente interesado! Requiere atención humana: \"#{message.content.truncate(100)}\"")

    Rails.logger.info "[SentimentAnalyzer] ⏸️ Seguimiento PAUSADO por intención positiva (#IP), administrador notificado (REGLA 13)"
  end

  def handle_neutral(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] ⚖️ NEUTRAL → Cliente informa que aún no completó la acción (sin rechazo)"

    # Calcular próxima fecha de seguimiento
    next_attempt_date = calculate_next_attempt_date(tracking)

    # Generar respuesta empática con IA
    reply_text = generate_contextualized_reply(tracking, message, :neutral, { next_date: next_attempt_date })

    # ⭐ Agregar marcador #IU (Intención Indefinida/Usuario pendiente)
    reply_text = "#{reply_text} #IU"

    # Enviar respuesta automática
    send_auto_reply(tracking, message, reply_text)

    # Actualizar contexto (NO cambiar estado, mantener activo)
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⚖️ Cliente indicó que aún no completó la acción: \"#{message.content.truncate(100)}\"\nSin rechazo, seguimiento continúa."
    )

    Rails.logger.info "[SentimentAnalyzer] ✅ Respuesta empática enviada, seguimiento continúa activo"
  end

  # Calcula la próxima fecha de intento del seguimiento
  def calculate_next_attempt_date(tracking)
    return nil if tracking.attempt_count >= tracking.max_attempts

    # Si está en modo auto retry, usar el intervalo de retry
    if tracking.auto_retry_mode?
      interval_value = tracking.retry_interval_value
      interval_unit = tracking.retry_interval_unit
      next_date = interval_value.send(interval_unit).from_now
    else
      # Calcular basado en el intervalo de tracking normal
      interval_value = tracking.interval_value
      interval_unit = tracking.interval_unit
      next_date = interval_value.send(interval_unit).from_now
    end

    # Formatear la fecha en formato legible
    inbox_timezone = tracking.inbox.timezone || 'America/Mexico_City'
    next_date.in_time_zone(inbox_timezone).strftime('%d/%m/%Y a las %H:%M')
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error calculando próxima fecha: #{e.message}"
    "próximamente"
  end

  def handle_unclear(tracking, message, confidence)
    Rails.logger.info "[SentimentAnalyzer] ❓ UNCLEAR (REGLA 18) → Respuesta poco clara, solicitando aclaración"

    # REGLA 18: Solicitar aclaración de manera educada
    reply_text = generate_contextualized_reply(tracking, message, :unclear)
    send_auto_reply(tracking, message, reply_text)

    # REGLA 18: NO modificar el estado del seguimiento, permanece activo
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n❓ Cliente envió respuesta poco clara: \"#{message.content.truncate(100)}\"\nSe solicitó aclaración."
    )

    Rails.logger.info "[SentimentAnalyzer] ✅ Aclaración solicitada, seguimiento permanece activo (REGLA 18)"
  end

  def handle_reschedule(tracking, message, sentiment_data)
    reschedule_data = sentiment_data[:reschedule_data] || {}

    Rails.logger.info "[SentimentAnalyzer] 📅 RESCHEDULE (REGLA 15, 16, 17, 27) → Cliente solicita reagendamiento"
    Rails.logger.info "[SentimentAnalyzer]    Datos extraídos: #{reschedule_data.inspect}"

    # REGLA 23: Calcular nueva fecha/hora usando zona horaria del inbox
    inbox_timezone = tracking.inbox.timezone || 'America/Mexico_City'
    new_datetime = calculate_reschedule_datetime(reschedule_data, inbox_timezone)

    Rails.logger.info "[SentimentAnalyzer]    Nueva fecha (#{inbox_timezone}): #{new_datetime.in_time_zone(inbox_timezone).strftime('%d/%m/%Y %H:%M %Z')}"
    Rails.logger.info "[SentimentAnalyzer]    Nueva fecha (UTC para DB): #{new_datetime.utc.strftime('%d/%m/%Y %H:%M %Z')}"

    # Reprogramar usando el método del modelo
    if tracking.reschedule_to(new_datetime)
      # ⭐ FIX: Formatear fecha/hora en la zona horaria del inbox para el mensaje al cliente
      inbox_tz = ActiveSupport::TimeZone[inbox_timezone]
      local_datetime = new_datetime.in_time_zone(inbox_tz)

      # Formato completo: "15/02/2026 a las 14:30"
      formatted_time = local_datetime.strftime('%d/%m/%Y a las %H:%M')

      # Descripción natural del cliente + fecha exacta
      natural_desc = reschedule_data[:natural] || ""

      # ⭐ SIEMPRE incluir la fecha/hora exacta en los datos para la respuesta
      reply_data = {
        natural_desc: natural_desc.present? ? "#{natural_desc} (#{formatted_time})" : formatted_time,
        formatted_time: formatted_time
      }

      # Generar confirmación con IA o usar mensaje por defecto
      reply_text = generate_contextualized_reply(tracking, message, :reschedule_success, reply_data)

      # ⭐ Agregar marcador #RA al final del mensaje
      reply_text = "#{reply_text} #RA"

      send_auto_reply(tracking, message, reply_text)

      tracking.update!(
        ai_context: "#{tracking.ai_context}\n\n📅 REAGENDADO: Cliente solicitó contacto para #{formatted_time}"
      )

      Rails.logger.info "[SentimentAnalyzer] ✅ Reagendado exitosamente a #{formatted_time}"
    else
      Rails.logger.error "[SentimentAnalyzer] ❌ No se pudo reagendar (tracking completado o cancelado)"

      # Generar mensaje de error con IA o usar mensaje por defecto
      reply_text = generate_contextualized_reply(tracking, message, :reschedule_error)
      send_auto_reply(tracking, message, reply_text)
    end
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error en reschedule: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

    # Generar mensaje de error general con IA o usar mensaje por defecto
    reply_text = generate_contextualized_reply(tracking, message, :general_error)
    send_auto_reply(tracking, message, reply_text)
  end

  # ==============================================================================
  # GENERACIÓN DE RESPUESTAS CONTEXTUALIZADAS CON IA
  # ==============================================================================

  # Genera una respuesta personalizada usando IA basada en el contexto del tracking
  # @param tracking [ContactTracking] El seguimiento activo
  # @param message [Message] El mensaje del cliente
  # @param reply_type [Symbol] Tipo de respuesta: :out_of_context, :rejected, :reschedule_success, :reschedule_error, :general_error
  # @param extra_data [Hash] Datos adicionales (ej: natural_desc para reschedule)
  # @return [String] Mensaje generado o mensaje por defecto si falla
  def generate_contextualized_reply(tracking, message, reply_type, extra_data = {})
    return default_reply(reply_type, extra_data) unless AI_GENERATED_REPLIES

    api_key_data = get_api_key(tracking.account)
    return default_reply(reply_type, extra_data) unless api_key_data && api_key_data[:key].present?

    begin
      prompt = build_reply_prompt(tracking, message, reply_type, extra_data)
      generated_reply = call_openai_for_reply(api_key_data[:key], prompt)

      if generated_reply.present?
        Rails.logger.info "[SentimentAnalyzer] ✨ Respuesta generada con IA (#{reply_type})"
        generated_reply
      else
        default_reply(reply_type, extra_data)
      end
    rescue StandardError => e
      Rails.logger.warn "[SentimentAnalyzer] ⚠️ Error generando respuesta con IA: #{e.message}, usando mensaje por defecto"
      default_reply(reply_type, extra_data)
    end
  end

  # Construye el prompt para generar la respuesta según el tipo
  def build_reply_prompt(tracking, message, reply_type, extra_data)
    contact_name = message.sender&.name || "cliente"
    objective = tracking.objective
    customer_message = message.content.truncate(200)

    # Obtener historial de mensajes
    message_history = get_tracking_message_history(tracking)

    base_context = <<~CONTEXT
      CONTEXTO DEL SEGUIMIENTO:
      - Objetivo del seguimiento: #{objective}
      - Nombre del cliente: #{contact_name}
      - Mensaje del cliente: "#{customer_message}"
      - Intento actual: #{tracking.attempt_count + 1} de #{tracking.max_attempts}

      #{message_history}
    CONTEXT

    case reply_type
    when :out_of_context
      <<~PROMPT
        #{base_context}

        CONTEXTO DE LA SITUACIÓN:
        El cliente envió un mensaje NO relacionado con el objetivo del seguimiento ("#{objective}").
        Puede ser: saludo, agradecimiento, pregunta aleatoria ("¿qué hora es?", "¿quién descubrió américa?"), o tema no relacionado.

        Mensaje del cliente: "#{customer_message}"

        TU TAREA:
        Genera una respuesta BREVE (máximo 2-3 líneas) que redirija al seguimiento.

        ⚠️ REGLAS CRÍTICAS:
        - NO respondas preguntas aleatorias del cliente (hora, historia, clima, etc.)
        - NO des información sobre temas NO relacionados con "#{objective}"
        - SÍ reconoce brevemente que preguntó algo ("Buena pregunta", "Interesante", etc.)
        - SIEMPRE redirige a tu función: ayudar con "#{objective}"

        ESTRUCTURA OBLIGATORIA (máximo 3 líneas):
        Línea 1: Reconoce brevemente el mensaje + tu función es "#{objective}"
        Línea 2: Ofrece reagendar si necesita más tiempo
        Línea 3: Un agente puede resolver otras dudas

        TONO: Cordial, directo, enfocado SOLO en el seguimiento

        EJEMPLO CORRECTO:
        Cliente: "¿Quién descubrió américa?"
        Respuesta: "Buena pregunta, pero mi función es ayudarte con el seguimiento de la cotización 😊
        Si necesitas reagendar, solo dime cuándo. Un agente puede resolver otras dudas."

        EJEMPLO CORRECTO:
        Cliente: "¿Qué hora es?"
        Respuesta: "Mi función es ayudarte con el seguimiento de la cotización 😊
        Si necesitas más tiempo para revisarla, avísame. Un agente puede ayudarte con otras consultas."

        EJEMPLO INCORRECTO (NO HAGAS ESTO):
        "Son las 2:00 PM. Cristóbal Colón descubrió américa en 1492..." ❌ (NO respondas la pregunta)

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :rejected
      <<~PROMPT
        #{base_context}

        TAREA:
        El cliente ha rechazado explícitamente el seguimiento (dijo "no me interesa", "cancelar", etc.).

        Genera una respuesta que:
        1. Respete su decisión de manera empática
        2. Confirme que el seguimiento ha sido cancelado
        3. Aclare que no recibirá más mensajes automáticos sobre este tema
        4. Deje la puerta abierta por si cambia de opinión en el futuro
        5. Agradezca su tiempo
        6. Sea breve (máximo 4 líneas)
        7. Use un tono respetuoso y profesional
        8. Si hay historial, úsalo para dar coherencia (evita repeticiones)

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :reschedule_success
      natural_desc = extra_data[:natural_desc] || "en el momento solicitado"
      formatted_time = extra_data[:formatted_time] || natural_desc
      <<~PROMPT
        #{base_context}
        - Nueva fecha/hora programada: #{formatted_time}

        TAREA:
        El cliente pidió reagendar y el sistema lo programó exitosamente.

        Genera una confirmación que:
        1. Confirme que se reagendó exitosamente
        2. ⭐ OBLIGATORIO: Incluye la fecha y hora EXACTA: "#{formatted_time}"
        3. Sea breve (máximo 2 líneas)
        4. Use un tono positivo y confirmatorio
        5. Puede usar un emoji apropiado (✅, 📅, etc.)
        6. Si hay historial, úsalo para dar coherencia a la conversación

        IMPORTANTE: El mensaje DEBE incluir "#{formatted_time}" para que el cliente sepa exactamente cuándo será contactado.

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :reschedule_error
      <<~PROMPT
        #{base_context}

        TAREA:
        El cliente pidió reagendar pero el sistema no pudo procesarlo (el seguimiento ya está completado o cancelado).

        Genera una disculpa que:
        1. Se disculpe por no poder reagendar
        2. Explique que un agente se pondrá en contacto pronto
        3. Sea breve (máximo 2 líneas)
        4. Use un tono empático

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :general_error
      <<~PROMPT
        #{base_context}

        TAREA:
        Hubo un error al procesar la solicitud de reagendamiento del cliente.

        Genera una disculpa que:
        1. Se disculpe por el inconveniente
        2. Mencione que un agente se pondrá en contacto pronto
        3. Sea breve (máximo 2 líneas)
        4. Use un tono empático y profesional

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :unclear
      <<~PROMPT
        #{base_context}

        TAREA (REGLA 18):
        El cliente envió una respuesta poco clara o ambigua. No se puede determinar si quiere reagendar, rechazar o qué necesita.

        Genera una solicitud de aclaración que:
        1. Sea amable y educada
        2. Mencione que no quedó claro lo que necesita
        3. Ofrezca ejemplos de respuestas claras (reagendar, cancelar, hacer preguntas)
        4. Sea breve (máximo 3 líneas)
        5. Use un tono cordial y comprensivo
        6. Si hay historial, úsalo para entender mejor el contexto y evitar repeticiones

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :interested
      <<~PROMPT
        #{base_context}

        TAREA (REGLA 13):
        El cliente mostró interés positivo en el seguimiento (dijo "me interesa", "quiero saber más", "cuéntame", etc.).

        Genera una respuesta de confirmación que:
        1. Confirme que entendiste su interés
        2. Mencione brevemente el objetivo del seguimiento
        3. Indique que un agente humano lo contactará pronto para continuar
        4. Sea breve (máximo 3 líneas)
        5. Use un tono positivo y entusiasta
        6. Puede usar un emoji apropiado (✨, 🎉, 👍, etc.)
        7. Si hay historial, úsalo para personalizar la respuesta y dar continuidad

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :neutral
      next_date = extra_data[:next_date] || "próximamente"
      <<~PROMPT
        #{base_context}

        TAREA:
        El cliente informa que AÚN NO ha completado la acción solicitada (revisar, ver, etc.),
        pero NO está rechazando el seguimiento. Es una respuesta neutral/informativa.

        Mensaje del cliente: "#{customer_message}"

        Genera una respuesta empática y sin presión que:
        1. Agradezca al cliente por informar (reconoce su comunicación)
        2. Muestre empatía y comprensión ("No hay problema", "Sin presión")
        3. Informe que tiene programado un próximo contacto para #{next_date}
        4. Ofrezca la opción de reagendar si prefiere otra fecha/hora
        5. Mencione brevemente el objetivo del seguimiento ("#{objective}")
        6. Sea breve (máximo 4 líneas)
        7. Use un tono amable, cordial y sin urgencia
        8. Puede usar un emoji apropiado (😊, 👍, ✅)
        9. Si hay historial, úsalo para personalizar y dar continuidad

        ⚠️ IMPORTANTE:
        - NO presionar al cliente
        - NO cerrar la conversación
        - Mantener la puerta abierta
        - Tono empático y flexible
        - USA LA FECHA REAL: #{next_date} (NO uses "[fecha]" como placeholder)

        Ejemplo de estructura (IMPORTANTE: usa la fecha real #{next_date}):
        "¡Gracias por avisarnos! No hay problema 😊
        Tenemos programado contactarte nuevamente el #{next_date} para #{objective}.
        Si prefieres que te recordemos en otro momento, solo avísanos."

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT

    when :question
      # ⭐ Prompt para responder preguntas del cliente sobre el seguimiento
      # Separa claramente: INFORMACIÓN (ai_context) vs COMPORTAMIENTO (complementary_prompt)

      context_info = tracking.ai_context.presence || "No hay información de contexto disponible"
      behavior_instructions = tracking.complementary_prompt.presence

      <<~PROMPT
        #{base_context}

        ══════════════════════════════════════════════════════════════
        📋 INFORMACIÓN DISPONIBLE (usa estos datos para responder):
        ══════════════════════════════════════════════════════════════
        #{context_info}

        #{behavior_instructions.present? ? "══════════════════════════════════════════════════════════════\n🎯 INSTRUCCIONES DE COMPORTAMIENTO:\n══════════════════════════════════════════════════════════════\n#{behavior_instructions}\n" : ""}
        ══════════════════════════════════════════════════════════════
        ❓ PREGUNTA DEL CLIENTE:
        ══════════════════════════════════════════════════════════════
        "#{customer_message}"

        TU TAREA:
        Responde la pregunta del cliente usando ÚNICAMENTE la información disponible arriba.

        REGLAS:
        1. Si tienes información suficiente → responde de forma clara y directa
        2. Si NO tienes información → indica amablemente que no cuentas con esos datos específicos
        3. Sé conciso (máximo 2-3 oraciones)
        4. NO inventes información que no esté en el contexto
        5. NO menciones que eres un bot o sistema automatizado
        6. NO menciones "seguimiento", "tracking" o términos técnicos
        7. Responde como un agente humano amable
        8. En español

        IMPORTANTE:
        - NO agregues #IF al final (eso se agrega automáticamente después)
        - NO modifiques ni cierres el seguimiento
        - Solo responde la pregunta puntual

        Responde SOLO con el mensaje, sin explicaciones adicionales.
      PROMPT
    end
  end

  # Llama a OpenAI para generar la respuesta
  def call_openai_for_reply(api_key, prompt)
    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 150,
      temperature: 0.7
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    response_body.dig('choices', 0, 'message', 'content')&.strip
  end

  # Retorna el mensaje por defecto según el tipo si la IA falla
  def default_reply(reply_type, extra_data = {})
    case reply_type
    when :out_of_context
      "Hola, soy un asistente automatizado de seguimiento. 🤖\n\n" \
      "Mi función es ayudarte a reagendar este contacto si lo necesitas en otro momento. " \
      "Por ejemplo, puedes responder:\n" \
      "• \"Recuérdame en 30 minutos\"\n" \
      "• \"Mañana a las 3pm\"\n" \
      "• \"En 2 horas\"\n\n" \
      "Para otras consultas relacionadas con este seguimiento, un agente humano te atenderá pronto."

    when :rejected
      "Entendido, respetamos completamente tu decisión. 🙏\n\n" \
      "Hemos cancelado el seguimiento y no recibirás más mensajes automáticos sobre este tema. " \
      "Si en el futuro cambias de opinión o necesitas algo, estaremos encantados de ayudarte.\n\n" \
      "¡Gracias por tu tiempo!"

    when :reschedule_success
      formatted_time = extra_data[:formatted_time] || extra_data[:natural_desc] || "en el momento solicitado"
      "✅ ¡Listo! He reagendado tu recordatorio para el #{formatted_time}. " \
      "Te contactaré en esa fecha y hora."

    when :reschedule_error
      "Lamentablemente no pude reagendar el seguimiento. " \
      "Un agente se pondrá en contacto contigo pronto."

    when :general_error
      "Lo siento, tuve un problema al procesar tu solicitud de reagendamiento. " \
      "Un agente se pondrá en contacto contigo pronto."

    when :unclear
      "Disculpa, no me quedó claro lo que necesitas. 🤔\n\n" \
      "¿Podrías ayudarme indicando si deseas:\n" \
      "• Reagendar el contacto (\"Recuérdame en 1 hora\", \"Mañana a las 3pm\")\n" \
      "• Cancelar el seguimiento (\"No me interesa\", \"Cancelar\")\n" \
      "• Hacer alguna pregunta sobre el servicio\n\n" \
      "¡Gracias por tu paciencia!"

    when :interested
      "¡Excelente! Me alegra saber que te interesa. ✨\n\n" \
      "Un agente de nuestro equipo se pondrá en contacto contigo muy pronto para continuar la conversación.\n\n" \
      "¡Gracias por tu interés!"

    when :neutral
      next_date = extra_data[:next_date] || "próximamente"
      "¡Gracias por avisarnos! No hay problema 😊\n\n" \
      "Entendemos que aún no has tenido oportunidad. " \
      "Tenemos programado contactarte nuevamente el #{next_date}.\n\n" \
      "Si prefieres que te recordemos en otro momento, solo avísanos."

    when :question
      "Gracias por tu pregunta. 😊\n\n" \
      "No cuento con información específica para responder en este momento. " \
      "Un agente se pondrá en contacto contigo pronto para resolver tu consulta."
    end
  end

  # ==============================================================================
  # GUARDAR ANÁLISIS
  # ==============================================================================
  def save_sentiment_analysis(tracking, sentiment_data, message)
    if tracking.respond_to?(:last_sentiment_analysis=)
      tracking.update_columns(
        last_sentiment_analysis: {
          sentiment: sentiment_data[:sentiment],
          confidence: sentiment_data[:confidence],
          method: sentiment_data[:method],
          message_content: message.content.truncate(200),
          analyzed_at: sentiment_data[:analyzed_at],
          message_id: message.id
        }
      )
    end

    tracking.increment!(:response_adjustments_count) if tracking.respond_to?(:response_adjustments_count)
  rescue StandardError => e
    Rails.logger.warn "[SentimentAnalyzer] No se pudo guardar análisis: #{e.message}"
  end

  # ==============================================================================
  # ENVIAR RESPUESTA AUTOMÁTICA
  # ==============================================================================
  def send_auto_reply(tracking, message, reply_content)
    return unless AUTO_REPLY_ENABLED

    conversation = message.conversation

    reply_message = Messages::MessageBuilder.new(
      bot_user(tracking.account),
      conversation,
      { content: reply_content, private: false }
    ).perform

    if reply_message.present?
      reply_message.content_attributes[:sentiment_auto_reply] = true
      reply_message.save!
      Rails.logger.info "[SentimentAnalyzer] ✅ Respuesta enviada"
    end
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error enviando respuesta: #{e.message}"
  end

  def bot_user(account)
    account.users.first ||
      AccountUser.where(account_id: account.id).first&.user ||
      User.first
  end

  # ==============================================================================
  # REGLA 12: Crear Mensaje Privado (Nota)
  # ==============================================================================
  def create_private_note(tracking, message, note_content)
    return unless message&.conversation

    conversation = message.conversation
    account = conversation.account

    Messages::MessageBuilder.new(
      user: bot_user(account),
      conversation: conversation,
      message_type: :activity,
      content: note_content,
      private: true
    ).perform

    Rails.logger.info "[SentimentAnalyzer] 📝 Nota privada creada para el agente"
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error creando nota privada: #{e.message}"
  end

  # ==============================================================================
  # REGLA 13: Notificar al Administrador
  # ==============================================================================
  def notify_admin_interested(tracking, message)
    return unless message&.conversation

    conversation = message.conversation
    account = conversation.account

    # Asignar conversación al administrador o al primer usuario disponible
    assignee = account.users.where(role: :administrator).first || account.users.first

    if assignee
      conversation.update(assignee_id: assignee.id)
      Rails.logger.info "[SentimentAnalyzer] 👤 Conversación asignada a administrador: #{assignee.name}"
    end

    # Crear notificación
    Notification.create!(
      account: account,
      user: assignee || account.users.first,
      notification_type: 'conversation_assignment',
      primary_actor: conversation,
      secondary_actor: message
    )

    Rails.logger.info "[SentimentAnalyzer] 🔔 Notificación enviada al administrador"
  rescue StandardError => e
    Rails.logger.error "[SentimentAnalyzer] ❌ Error notificando administrador: #{e.message}"
  end
end
