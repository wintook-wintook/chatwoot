# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - BOT CONVERSACIONAL DE SEGUIMIENTOS
# ================================================================================
# Job: ContactTrackingResponseAnalyzerJob
# Versión: 7.0.0 - Rediseño completo: bot conversacional + detección de acciones
# Fecha: 2026-04-20
#
# ARQUITECTURA:
#   Ante cualquier mensaje del cliente con seguimiento activo/pausado:
#   → Detecta si el mensaje es una intención de acción (rejected, interested, reschedule)
#   → Si hay acción: la ejecuta con respuesta específica
#   → Si no hay acción: responde conversacionalmente con IA (como GPT, enfocado en el objetivo)
#
# INTENCIONES DE ACCIÓN (modifican estado del tracking):
#   1. rejected    → Cancela seguimiento + despedida
#   2. interested  → Pausa seguimiento + notifica al agente
#   3. reschedule  → Reagenda + confirmación
#
# COMPORTAMIENTO CONVERSACIONAL (todo lo demás):
#   → Responde con IA como un asesor humano enfocado en el objetivo
#   → Usa historial de conversación para respuestas contextualizadas
#   → No modifica el estado del tracking
#
# PARA REVERTIR:
#   → Restaurar desde contact_tracking_response_analyzer_job.rb.bak_20260420_195017
# ================================================================================

class ContactTrackingResponseAnalyzerJob < ApplicationJob
  queue_as :default

  AUTO_REPLY_ENABLED   = ENV.fetch('SENTIMENT_ENABLE_AUTO_REPLY', 'true') == 'true'
  AI_GENERATED_REPLIES = ENV.fetch('SENTIMENT_AI_GENERATED_REPLIES', 'true') == 'true'
  DETECT_INTENT        = ENV.fetch('TRACKING_DETECT_INTENT', 'false') == 'true'
  DEBUG_TAG            = ENV.fetch('TRACKING_DEBUG_TAG', 'false') == 'true'

  # ==============================================================================
  # Método Principal
  # ==============================================================================
  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming?
    return unless message_has_content?(message)

    Rails.logger.info "[Coordinator] 🔍 Mensaje ##{message_id}: \"#{message_text_for_ai(message).truncate(80)}\""

    active_trackings = find_active_trackings(message)

    botseller_available = defined?(BotSeller::Dispatcher) && BotSeller::Dispatcher.configured?

    if active_trackings.any?
      Rails.logger.info "[Coordinator] 📋 #{active_trackings.count} seguimiento(s) activo(s)"
      tracking_replied = active_trackings.any? { |t| process_message_for_tracking(t, message) }
      if !tracking_replied && botseller_available
        Rails.logger.info '[Coordinator] 🤖 Tracking sin respuesta → escalando a [@botseller]'
        BotSeller::Dispatcher.new(message).dispatch
      end
    elsif botseller_available
      Rails.logger.info '[Coordinator] 🤖 Sin seguimiento, @botseller disponible → [@botseller]'
      BotSeller::Dispatcher.new(message).dispatch
    end

  rescue StandardError => e
    Rails.logger.error "[Coordinator] ❌ Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  private

  # ==============================================================================
  # Procesamiento principal por tracking
  # ==============================================================================
  # Retorna true si envió una respuesta, false si no (para que el Coordinator
  # decida si escala a BotSeller)
  def process_message_for_tracking(tracking, message)
    Rails.logger.info "[TrackingBot] 🔍 Tracking ##{tracking.id} (#{tracking.status})"

    # [1] Keywords — prioridad máxima, sin IA (solo si hay texto)
    if message.content.present? && defined?(ContactTrackings::KeywordActionService)
      keyword_service = ContactTrackings::KeywordActionService.new(tracking, message.content, 'incoming')
      if keyword_service.call
        Rails.logger.info "[TrackingBot] ⌨️  Acción por keyword ejecutada — skip RouterService"
        return true
      end
    end

    # [2] RouterService — clasifica ruta via IA
    route_result = classify_route(tracking, message)
    route        = route_result[:route]

    replied = case route
              when :rejected
                handle_rejected(tracking, message, route_result[:confidence])
                true
              when :interested
                handle_interested(tracking, message, route_result[:confidence])
                true
              when :reschedule
                handle_reschedule(tracking, message, route_result)
                true
              when :discourse
                Rails.logger.info '[TrackingBot] 📚 Derivando a @discourse'
                kbase_replied = KnowledgeBaseResponseService.new(message, tracking: tracking).perform
                if kbase_replied
                  true
                else
                  Rails.logger.info '[TrackingBot] ⚠️ KBase sin resultados → fallback conversacional'
                  generate_and_send_conversational_reply(tracking, message)
                end
              when :botseller
                if BotSeller::Dispatcher.configured?
                  Rails.logger.info '[TrackingBot] 🤖 Derivando a @botseller'
                  BotSeller::Dispatcher.new(message).dispatch
                  true
                else
                  generate_and_send_conversational_reply(tracking, message)
                end
              else # :tracking
                replied = generate_and_send_conversational_reply(tracking, message)
                if !replied && kbase_available?(message, tracking)
                  Rails.logger.info '[TrackingBot] 📚 Sin respuesta conversacional → fallback @discourse'
                  KnowledgeBaseResponseService.new(message, tracking: tracking).perform
                  true
                else
                  replied
                end
              end

    save_sentiment_analysis(tracking, route_result, message)
    replied

  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en tracking ##{tracking.id}: #{e.message}"
    false
  end

  def classify_route(tracking, message)
    unless DETECT_INTENT
      Rails.logger.info '[TrackingBot] ⏭️  RouterService desactivado (TRACKING_DETECT_INTENT=false) → :tracking'
      return { route: :tracking, confidence: 1.0, method: 'disabled' }
    end

    api_key_data = get_api_key(message.account)
    unless api_key_data&.dig(:key).present?
      Rails.logger.info '[TrackingBot] ⚠️  Sin API key → :tracking'
      return { route: :tracking, confidence: 1.0, method: 'no_key' }
    end

    ContactTrackings::RouterService.new(
      tracking,
      message,
      api_key_data[:key],
      kbase_available:     kbase_available?(message, tracking),
      botseller_available: BotSeller::Dispatcher.configured?,
      recent_messages:     get_recent_context(message, 4)
    ).classify
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ RouterService falló: #{e.message} → :tracking"
    { route: :tracking, confidence: 1.0, method: 'error' }
  end

  def kbase_available?(message, tracking = nil)
    account = message.account
    inbox   = message.inbox
    hook    = account.hooks.find_by(app_id: 'discourse', inbox_id: inbox.id, status: 'enabled')
    url     = hook&.settings&.dig('url').presence || ENV.fetch('DISCOURSE_URL', '')
    return false unless url.present?

    # Si se pasa un tracking, verificar que la plantilla mencione @discourse
    return tracking.complementary_prompt.to_s.include?('@discourse') if tracking.present?

    true
  rescue StandardError
    false
  end

  # ==============================================================================
  # Búsqueda de Trackings (incluye pausados)
  # ==============================================================================
  def find_active_trackings(message)
    ContactTracking
      .where(contact_id: message.sender&.id)
      .where(conversation_id: message.conversation_id)
      .where(status: %w[active scheduled pending paused])
  end

  # ==============================================================================
  # Respuesta Conversacional (cuando ruta es :tracking)
  # ==============================================================================
  def generate_and_send_conversational_reply(tracking, message)
    Rails.logger.info "[TrackingBot] 💬 Generando respuesta conversacional para tracking ##{tracking.id}"
    reply_text = generate_conversational_reply(tracking, message)
    return false if reply_text.blank?

    reply_text = "#{reply_text}\n\n@TrackingBot" if DEBUG_TAG
    send_auto_reply(tracking, message, reply_text)
    Rails.logger.info '[TrackingBot] ✅ Respuesta enviada → respondió TrackingBot'
    true
  end

  def generate_conversational_reply(tracking, message)
    return nil unless AI_GENERATED_REPLIES

    api_key_data = get_api_key(tracking.account)
    return nil unless api_key_data&.dig(:key).present?

    begin
      contact_name    = message.sender&.name || 'cliente'
      first_name      = contact_name.split.first
      message_history = get_tracking_message_history(tracking)

      ia_note = tracking.contact.notes.for_ia.first
      contact_profile = ia_note.present? ?
        "PERFIL DEL CONTACTO: #{ActionController::Base.helpers.strip_tags(ia_note.content)}\n" : ''

      tracking.reload
      inbox_timezone = message.conversation.inbox.timezone || 'America/Mexico_City'
      next_contact = tracking.scheduled_for.in_time_zone(inbox_timezone).strftime('%d/%m/%Y a las %H:%M')

      # Strip @discourse markers so GPT doesn't output them literally as text
      clean_cp = tracking.complementary_prompt.to_s.gsub(/@discourse\b[^\n]*/i, '').strip

      system_prompt = <<~SYSTEM.strip
        Eres un asesor de ventas para #{tracking.account.name}.
        Responde como un humano amable y conocedor del tema. NUNCA menciones que eres un bot o sistema automático.

        #{contact_profile}
        OBJETIVO DE LA CONVERSACIÓN: #{tracking.objective}
        PRÓXIMO CONTACTO PROGRAMADO: #{next_contact} (si el cliente pide reagendar, infórmale amablemente que su próximo contacto ya está programado para esa fecha y que si necesita cambiarlo debe comunicarse con un asesor)
        #{tracking.ai_context.present? ? "BASE DE CONOCIMIENTO:\n#{tracking.ai_context.truncate(800)}\n" : ""}
        #{clean_cp.present? ? "INSTRUCCIONES ADICIONALES:\n#{clean_cp}" : ""}
      SYSTEM

      user_prompt = <<~USER.strip
        #{message_history.present? ? "#{message_history}\n\n" : ""}Responde al siguiente mensaje de #{first_name}:
        "#{message_text_for_ai(message).truncate(300)}"

        Máximo 4 líneas. Tono natural y conversacional.
        No uses prefijos como "Asesor:" o "Bot:". No incluyas comillas al inicio ni al final.
      USER

      reply = call_openai_for_reply(api_key_data[:key], [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ])
      return reply if reply.present?
    rescue StandardError => e
      Rails.logger.warn "[TrackingBot] ⚠️ Error en respuesta conversacional: #{e.message}"
    end

    nil
  end

  def conversational_fallback(tracking, message)
    first_name = message.sender&.name&.split&.first || 'Hola'
    topic = tracking.objective.split('.').first.downcase
    "#{first_name}, recibí tu mensaje. Un asesor de nuestro equipo te contactará pronto para ayudarte con #{topic}."
  end

  # ==============================================================================
  # Handlers de Acciones
  # ==============================================================================
  def handle_rejected(tracking, message, confidence)
    Rails.logger.info "[TrackingBot] ❌ REJECTED → Pausando seguimiento"

    reply_text = generate_action_reply(tracking, message, :rejected)
    send_auto_reply(tracking, message, reply_text)
    tracking.disable_auto_retry_mode!
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏸️ [IN] PAUSADO: Cliente rechazó\nMensaje: \"#{message_text_for_ai(message).truncate(100)}\""
    )
    tracking.pause!
    create_private_note(tracking, message, "Cliente rechazó el seguimiento: \"#{message_text_for_ai(message).truncate(100)}\"")
    Rails.logger.info "[TrackingBot] ⏸️ Seguimiento pausado por rechazo del cliente"
  end

  def handle_interested(tracking, message, confidence)
    Rails.logger.info "[TrackingBot] ✅ INTERESTED → Pausando seguimiento"

    tracking.disable_auto_retry_mode!
    reply_text = generate_action_reply(tracking, message, :interested)
    send_auto_reply(tracking, message, reply_text)
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏸️ [IP] PAUSADO: Cliente mostró interés\nMensaje: \"#{message_text_for_ai(message).truncate(100)}\"\nRequiere atención humana."
    )
    tracking.pause!
    notify_admin_interested(tracking, message)
    create_private_note(tracking, message, "⏸️ Seguimiento PAUSADO - ¡Cliente interesado! Requiere atención humana: \"#{message_text_for_ai(message).truncate(100)}\"")
    Rails.logger.info "[TrackingBot] ⏸️ Seguimiento pausado, administrador notificado"
  end

  def handle_reschedule(tracking, message, action_data)
    Rails.logger.info "[TrackingBot] 📅 RESCHEDULE → Reagendando seguimiento"

    reschedule_data = action_data[:reschedule_data] || {}
    inbox_timezone = message.conversation.inbox.timezone || 'America/Mexico_City'

    if reschedule_data.empty?
      Rails.logger.info "[TrackingBot] ❓ Sin fecha/hora → solicitando cuándo"
      reply_text = generate_action_reply(tracking, message, :reschedule_ask_when)
      send_auto_reply(tracking, message, reply_text)
      tracking.update!(
        ai_context: "#{tracking.ai_context}\n\n⏳ ESPERANDO FECHA: Cliente quiere reagendar pero no indicó cuándo."
      )
      return
    end

    new_time = calculate_reschedule_datetime(reschedule_data, inbox_timezone)
    formatted_time = new_time.in_time_zone(inbox_timezone).strftime('%d/%m/%Y a las %H:%M')
    natural_desc = reschedule_data[:natural] || formatted_time

    success = tracking.reschedule_to(new_time)

    if success
      reply_text = generate_action_reply(tracking, message, :reschedule_success, {
        natural_desc: natural_desc,
        formatted_time: formatted_time
      })
      send_auto_reply(tracking, message, reply_text)
      Rails.logger.info "[TrackingBot] ✅ Reagendado para #{formatted_time}"
    else
      reply_text = generate_action_reply(tracking, message, :reschedule_error)
      send_auto_reply(tracking, message, reply_text)
      Rails.logger.error "[TrackingBot] ❌ No se pudo reagendar"
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en reschedule: #{e.message}"
    send_auto_reply(tracking, message, generate_action_reply(tracking, message, :general_error))
  end

  # ==============================================================================
  # Generación de respuestas para acciones específicas
  # ==============================================================================
  def generate_action_reply(tracking, message, reply_type, extra_data = {})
    return default_reply(reply_type, extra_data) unless AI_GENERATED_REPLIES

    api_key_data = get_api_key(tracking.account)
    return default_reply(reply_type, extra_data) unless api_key_data&.dig(:key).present?

    begin
      prompt = build_action_prompt(tracking, message, reply_type, extra_data)
      return default_reply(reply_type, extra_data) unless prompt.present?

      reply = call_openai_for_reply(api_key_data[:key], [
        {
          role: 'system',
          content: 'Eres un asesor de ventas. Responde SOLO con el mensaje final para el cliente. ' \
                   'NUNCA incluyas prefijos de nombre (ej: "Bot:", "Asesor:") ni explicaciones adicionales.'
        },
        { role: 'user', content: prompt }
      ])
      return reply if reply.present?
    rescue StandardError => e
      Rails.logger.warn "[TrackingBot] ⚠️ Error generando respuesta de acción: #{e.message}"
    end

    default_reply(reply_type, extra_data)
  end

  def build_action_prompt(tracking, message, reply_type, extra_data)
    first_name = message.sender&.name&.split&.first || 'cliente'
    objective  = tracking.objective
    behavior         = tracking.complementary_prompt.presence || ''
    customer_message = message_text_for_ai(message).truncate(300)
    base = "Cliente: #{first_name}\nObjetivo: #{objective}\n#{behavior.present? ? "Instrucciones: #{behavior}\n" : ""}Mensaje del cliente: \"#{customer_message}\"\n\n"

    case reply_type
    when :rejected
      "#{base}El cliente rechazó el seguimiento. Genera una despedida breve (2-3 líneas) que respete su decisión, confirme que no recibirá más mensajes automáticos y deje la puerta abierta."
    when :interested
      "#{base}El cliente mostró interés. Genera una respuesta breve (2-3 líneas) que confirme con entusiasmo e indique que un asesor lo contactará pronto."
    when :reschedule_success
      formatted_time = extra_data[:formatted_time] || extra_data[:natural_desc] || "en el momento solicitado"
      "#{base}El seguimiento fue reagendado para: #{formatted_time}. Genera una confirmación breve (1-2 líneas) mencionando la fecha/hora exacta."
    when :reschedule_ask_when
      "#{base}El cliente quiere reagendar pero no indicó cuándo. Pregúntale de forma natural para qué fecha u hora prefiere. Máximo 2 líneas."
    end
  end

  def default_reply(reply_type, extra_data = {})
    case reply_type
    when :rejected
      "Entendido, respetamos completamente tu decisión. 🙏 No recibirás más mensajes automáticos sobre este tema. ¡Gracias por tu tiempo!"
    when :interested
      "¡Excelente! Me alegra saber que te interesa. ✨ Un asesor de nuestro equipo se pondrá en contacto contigo muy pronto."
    when :reschedule_success
      formatted_time = extra_data[:formatted_time] || extra_data[:natural_desc] || "en el momento solicitado"
      "✅ ¡Listo! He reagendado tu recordatorio para el #{formatted_time}."
    when :reschedule_ask_when
      "Con gusto te reagendo 📅 ¿Para qué fecha y hora prefieres que te contactemos?"
    when :reschedule_error, :general_error
      "Lo siento, tuve un problema al procesar tu solicitud. Un agente se pondrá en contacto contigo pronto."
    end
  end

  # ==============================================================================
  # OpenAI - Llamada unificada
  # ==============================================================================
  def call_openai_for_reply(api_key, messages)
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
      messages: messages,
      max_tokens: 250,
      temperature: 0.7
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    reply = response_body.dig('choices', 0, 'message', 'content')&.strip
    reply&.gsub(/\A[A-Za-záéíóúñÁÉÍÓÚÑ\s]{2,20}:\s*\n?/, '')&.strip
  end

  # ==============================================================================
  # Guardar análisis
  # ==============================================================================
  def save_sentiment_analysis(tracking, route_result, message)
    return unless tracking.respond_to?(:last_sentiment_analysis=)

    tracking.update_columns(
      last_sentiment_analysis: {
        sentiment:       route_result&.dig(:route)&.to_s || 'tracking',
        confidence:      route_result&.dig(:confidence) || 1.0,
        method:          route_result&.dig(:method) || 'tracking',
        message_content: message_text_for_ai(message).truncate(200),
        analyzed_at:     Time.current,
        message_id:      message.id
      }
    )
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] No se pudo guardar análisis: #{e.message}"
  end

  # ==============================================================================
  # Enviar respuesta automática
  # ==============================================================================
  def send_auto_reply(tracking, message, reply_content)
    return unless AUTO_REPLY_ENABLED
    return if reply_content.blank?

    reply_message = Messages::MessageBuilder.new(
      bot_user(tracking.account),
      message.conversation,
      { content: reply_content, private: false }
    ).perform

    if reply_message.present?
      reply_message.content_attributes[:sentiment_auto_reply] = true
      reply_message.save!
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error enviando respuesta: #{e.message}"
  end

  def bot_user(account)
    account.users.first ||
      AccountUser.where(account_id: account.id).first&.user ||
      User.first
  end

  # ==============================================================================
  # Notas privadas y notificaciones
  # ==============================================================================
  def create_private_note(tracking, message, note_content)
    return unless message&.conversation

    Messages::MessageBuilder.new(
      user: bot_user(tracking.account),
      conversation: message.conversation,
      message_type: :activity,
      content: note_content,
      private: true
    ).perform

    Rails.logger.info "[TrackingBot] 📝 Nota privada creada"
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error creando nota privada: #{e.message}"
  end

  def notify_admin_interested(tracking, message)
    return unless message&.conversation

    conversation = message.conversation
    account = conversation.account
    assignee = account.users.where(role: :administrator).first || account.users.first

    if assignee
      conversation.update(assignee_id: assignee.id)
      Rails.logger.info "[TrackingBot] 👤 Conversación asignada a: #{assignee.name}"
    end

    Notification.create!(
      account: account,
      user: assignee || account.users.first,
      notification_type: 'conversation_assignment',
      primary_actor: conversation,
      secondary_actor: message
    )

    Rails.logger.info "[TrackingBot] 🔔 Notificación enviada al administrador"
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error notificando administrador: #{e.message}"
  end

  # ==============================================================================
  # Utilidades
  # ==============================================================================
  def get_api_key(account)
    if account
      hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
      return { key: hook.settings['api_key'], source: 'account_integration' } if hook&.settings&.dig('api_key').present?
    end
    return { key: ENV['OPENAI_API_KEY'], source: 'env' } if ENV['OPENAI_API_KEY'].present?
    nil
  end

  def get_recent_context(message, limit = 4)
    return '' unless message.conversation_id.present?

    messages = Message.where(conversation_id: message.conversation_id)
                      .where(message_type: [0, 1])
                      .where.not(id: message.id)
                      .order(created_at: :desc)
                      .limit(limit)
                      .reverse

    return '' if messages.empty?

    messages.map do |msg|
      sender = msg.incoming? ? 'Cliente' : 'Bot'
      "#{sender}: #{message_text_for_ai(msg).truncate(120)}"
    end.join("\n")
  rescue StandardError
    ''
  end

  def get_tracking_message_history(tracking)
    return '' unless tracking.conversation_id.present?

    messages = Message.where(conversation_id: tracking.conversation_id)
                      .where('created_at > ?', tracking.created_at)
                      .where(message_type: [0, 1])
                      .order(created_at: :asc)
                      .limit(20)

    return '' if messages.empty?

    lines = messages.map do |msg|
      sender = msg.incoming? ? 'Cliente' : 'Bot'
      "[#{msg.created_at.strftime('%d/%m %H:%M')}] #{sender}: #{message_text_for_ai(msg).truncate(200)}"
    end

    "HISTORIAL DE CONVERSACIÓN:\n#{lines.join("\n")}"
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error obteniendo historial: #{e.message}"
    ''
  end

  def message_has_content?(message)
    message.content.present? || message.attachments.present?
  end

  def message_text_for_ai(message)
    parts = []
    parts << message.content.strip if message.content.present?

    message.attachments.each do |att|
      case att.file_type.to_s
      when 'audio'  then parts << '[mensaje de voz]'
      when 'image'  then parts << '[imagen adjunta]'
      when 'video'  then parts << '[video adjunto]'
      when 'file'
        fname = att.file&.blob&.filename.to_s.presence || 'documento'
        parts << "[archivo adjunto: #{fname}]"
      when 'location'
        parts << "[ubicación compartida: #{att.coordinates_lat}, #{att.coordinates_long}]"
      else
        parts << '[adjunto]'
      end
    end

    parts.join(' ').presence || '[sin contenido]'
  rescue StandardError
    message.content.to_s
  end

  def get_template_content(tracking)
    return nil unless tracking.use_template_for_current_attempt?

    template_name = tracking.current_template
    return nil unless template_name

    channel = tracking.inbox.channel
    return nil unless channel.respond_to?(:message_templates)
    return nil unless channel.message_templates.is_a?(Array)

    template = channel.message_templates.find { |t| t['name'] == template_name }
    template&.dig('components')&.find { |c| c['type'] == 'BODY' }&.dig('text')&.truncate(300)
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error obteniendo plantilla: #{e.message}"
    nil
  end

  # ==============================================================================
  # Cálculo de fechas para reagendamiento
  # ==============================================================================
  def calculate_reschedule_datetime(reschedule_data, timezone = 'America/Mexico_City')
    Time.use_zone(timezone) do
      now = Time.current

      return reschedule_data[:relative_minutes].minutes.from_now if reschedule_data[:relative_minutes]
      return reschedule_data[:relative_hours].hours.from_now if reschedule_data[:relative_hours]
      return reschedule_data[:relative_days].days.from_now.change(hour: 10, min: 0, sec: 0) if reschedule_data[:relative_days]

      if reschedule_data[:specific_time]
        hour, minute = reschedule_data[:specific_time].split(':').map(&:to_i)
        if reschedule_data[:specific_date]
          Time.zone.parse(reschedule_data[:specific_date]).change(hour: hour, min: minute, sec: 0)
        else
          target = now.change(hour: hour, min: minute, sec: 0)
          target < now ? target + 1.day : target
        end
      elsif reschedule_data[:specific_date]
        Time.zone.parse("#{reschedule_data[:specific_date]} 10:00:00")
      else
        1.hour.from_now
      end
    end
  end
end
