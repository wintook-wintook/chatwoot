# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Job: ContactTrackingJob (VERSIÓN FINAL)
# Versión: 3.0.0 (Con detección de idioma y ventana WhatsApp)
# ================================================================================

class ContactTrackingJob < ApplicationJob
  queue_as :scheduled_jobs

  # ⭐ GPT-style: incluir historial real de conversación en el prompt
  GPT_HISTORY_ENABLED = ENV.fetch('TRACKING_GPT_HISTORY_ENABLED', 'false') == 'true'

  def perform(tracking_id)
    tracking = ContactTracking.find_by(id: tracking_id)
    return unless tracking

    # ⭐ LOCK PESIMISTA: Evita ejecución simultánea del mismo tracking
    tracking.with_lock do
      # Recargar para obtener el estado más reciente dentro del lock
      tracking.reload

      # Verificar estado después de obtener el lock
      # ⭐ IMPORTANTE: No ejecutar si está pausado, cancelado, completado o ya activo
      if tracking.paused?
        Rails.logger.info "[ContactTracking] ⏸️  Tracking #{tracking.id} está PAUSADO - Job ignorado"
        return
      end
      return if tracking.cancelled? || tracking.completed? || tracking.objective_met?
      return if tracking.active?  # Ya se está ejecutando en otro job

      # ⭐ FIX: Protección contra jobs duplicados que esperaron el lock
      # Si el último intento fue hace menos de 60 segundos, este job es duplicado
      if tracking.last_attempt_at.present? && tracking.last_attempt_at > 60.seconds.ago
        Rails.logger.warn "[ContactTracking] ⚠️  Job duplicado detectado para tracking #{tracking.id}"
        Rails.logger.warn "[ContactTracking]    Último intento: #{tracking.last_attempt_at}"
        Rails.logger.warn "[ContactTracking]    Tiempo transcurrido: #{(Time.current - tracking.last_attempt_at).to_i} segundos"
        return
      end

      # ⭐ FIX: Verificar que la hora programada ya pasó (no ejecutar jobs adelantados)
      if tracking.scheduled_for > Time.current
        Rails.logger.warn "[ContactTracking] ⚠️  Job adelantado para tracking #{tracking.id}"
        Rails.logger.warn "[ContactTracking]    Programado: #{tracking.scheduled_for}"
        Rails.logger.warn "[ContactTracking]    Ahora: #{Time.current}"
        return
      end

      # ⭐ LOGS DE DEBUG
      Rails.logger.info "[ContactTracking] ================================"
      Rails.logger.info "[ContactTracking] 🔒 LOCK ADQUIRIDO - Ejecutando tracking ##{tracking.id}"
      Rails.logger.info "[ContactTracking] 📋 Objetivo: #{tracking.objective}"
      Rails.logger.info "[ContactTracking] 🔢 Intento: #{tracking.attempt_count + 1}/#{tracking.max_attempts}"
      Rails.logger.info "[ContactTracking] 📱 Plantillas configuradas: #{tracking.whatsapp_templates.inspect}"
      Rails.logger.info "[ContactTracking] 🏷️  current_template: #{tracking.current_template.inspect}"
      Rails.logger.info "[ContactTracking] ✅ use_template_for_current_attempt?: #{tracking.use_template_for_current_attempt?}"
      Rails.logger.info "[ContactTracking] 📡 Canal tipo: #{tracking.inbox.channel_type}"
      Rails.logger.info "[ContactTracking] ================================"

      tracking.update!(status: 'active', last_attempt_at: Time.current)

      # Verificar condiciones
      has_template = tracking.use_template_for_current_attempt?
      is_whatsapp = is_whatsapp_channel?(tracking)
      window_open = whatsapp_window_open?(tracking)

      Rails.logger.info "[ContactTracking] 🔍 Análisis de envío:"
      Rails.logger.info "[ContactTracking]    - Canal WhatsApp: #{is_whatsapp}"
      Rails.logger.info "[ContactTracking]    - Tiene plantilla: #{has_template}"
      Rails.logger.info "[ContactTracking]    - Ventana 24h: #{window_open ? 'ABIERTA ✅' : 'CERRADA ❌'}"
  
      # Decisión de envío
      if is_whatsapp && !window_open && !has_template
        # CASO 1: WhatsApp ventana CERRADA sin plantilla - ERROR
        Rails.logger.error "[ContactTracking] ❌ IMPOSIBLE ENVIAR:"
        Rails.logger.error "[ContactTracking]    - Ventana de 24h cerrada"
        Rails.logger.error "[ContactTracking]    - No hay plantilla configurada"
        Rails.logger.error "[ContactTracking]    - Solución: Configure plantillas o espere mensaje del cliente"
        tracking.update!(
          status: 'failed',
          last_error: 'WhatsApp 24h window closed and no template configured'
        )
        return
      elsif is_whatsapp && !window_open && has_template
        # CASO 2: WhatsApp ventana CERRADA con plantilla - SOLO PLANTILLA
        Rails.logger.info "[ContactTracking] 📱 ✅ VENTANA CERRADA → Enviando solo PLANTILLA"
        success = send_whatsapp_template(tracking)
      elsif is_whatsapp && window_open
        # CASO 3: WhatsApp ventana ABIERTA - MENSAJE GENERADO CON IA (plantillas ignoradas)
        Rails.logger.info "[ContactTracking] 🪟 ✅ VENTANA ABIERTA → Mensaje generado con IA pura (plantillas ignoradas)"

        message_body = generate_message(tracking)
        success = send_message_via_chatwoot(tracking, message_body)

        if success
          Rails.logger.info "[ContactTracking] ✅ Mensaje personalizado enviado con IA"
        else
          Rails.logger.error "[ContactTracking] ❌ Error al enviar mensaje personalizado"
        end
      else
        # CASO 4: Otro canal (no WhatsApp)
        Rails.logger.info "[ContactTracking] 💬 USANDO MENSAJE NORMAL (canal: #{tracking.inbox.channel_type})"
        message_body = generate_message(tracking)
        success = send_message_via_chatwoot(tracking, message_body)
      end
  
      # Manejo post-envío
      if success
        # ⭐ NUEVA LÓGICA: Detectar modo reintento automático (reagendamiento)
        if tracking.auto_retry_mode?
          # Incrementar contador de repeticiones del mismo intento
          tracking.increment!(:response_adjustments_count)
          current_repetition = tracking.response_adjustments_count

          Rails.logger.info "[ContactTracking] 🔁 MODO REINTENTO ACTIVO"
          Rails.logger.info "[ContactTracking]    Plantilla actual: #{tracking.attempt_count + 1}"
          Rails.logger.info "[ContactTracking]    Repetición: #{current_repetition}/#{tracking.max_attempts}"

          # ⭐ REGLA: Si se alcanzó max_attempts repeticiones del mismo intento, pasar al siguiente
          if current_repetition >= tracking.max_attempts
            Rails.logger.info "[ContactTracking] ⚠️  Alcanzado máximo de repeticiones para este intento"

            # Desactivar modo reintento y pasar al siguiente intento
            tracking.disable_auto_retry_mode!
            new_attempt_count = tracking.attempt_count + 1

            # Verificar si hay más plantillas disponibles
            if new_attempt_count >= tracking.whatsapp_templates_count
              tracking.update!(
                status: 'completed',
                attempt_count: new_attempt_count,
                response_adjustments_count: 0,
                ai_context: tracking.ai_context  # Guardar el cambio de disable_auto_retry_mode!
              )
              Rails.logger.info "[ContactTracking] ✅ Tracking ##{tracking.id} completado - Sin más plantillas disponibles"
            else
              # Programar siguiente intento con la nueva plantilla
              next_run = tracking.retry_interval_value.send(tracking.retry_interval_unit).from_now
              tracking.update!(
                scheduled_for: next_run,
                status: 'scheduled',
                attempt_count: new_attempt_count,
                response_adjustments_count: 0,
                ai_context: tracking.ai_context  # Guardar el cambio de disable_auto_retry_mode!
              )
              Rails.logger.info "[ContactTracking] 📅 Pasando a plantilla #{new_attempt_count + 1} para #{next_run.strftime('%d/%m/%Y %H:%M')}"
            end
          else
            # Aún hay repeticiones disponibles, programar mismo intento
            next_run = tracking.retry_interval_value.send(tracking.retry_interval_unit).from_now
            tracking.update!(
              scheduled_for: next_run,
              status: 'scheduled'
              # attempt_count NO cambia - se mantiene en la misma plantilla
            )
            Rails.logger.info "[ContactTracking] 🔁 Reprogramado mismo intento (repetición #{current_repetition + 1}) para #{next_run.strftime('%d/%m/%Y %H:%M')}"
          end
        else
          # Modo normal: Incrementar attempt_count
          tracking.increment!(:attempt_count)
          Rails.logger.info "[ContactTracking] ✅ Mensaje enviado - Tracking ##{tracking.id} (intento #{tracking.attempt_count}/#{tracking.max_attempts})"

          if tracking.attempt_count >= tracking.max_attempts
            tracking.update!(status: 'completed')
            Rails.logger.info "[ContactTracking] ✅ Tracking ##{tracking.id} completado"
          else
            next_run = tracking.next_scheduled_time

            if next_run
              tracking.update!(scheduled_for: next_run, status: 'scheduled')
              # NO llamar schedule_job aquí - el callback after_update lo hace automáticamente
              Rails.logger.info "[ContactTracking] 📅 Tracking ##{tracking.id} reprogramado para #{next_run}"
            else
              tracking.update!(status: 'completed')
              Rails.logger.info "[ContactTracking] ✅ Tracking ##{tracking.id} completado (sin intervalo)"
            end
          end
        end
      else
        tracking.update!(status: 'failed', last_error: 'Failed to send message')
        Rails.logger.error "[ContactTracking] ❌ Tracking ##{tracking.id} falló al enviar mensaje"
      end
    end  # Cierra with_lock
  rescue StandardError => e
    tracking&.update(status: 'failed', last_error: e.message)
    Rails.logger.error "[ContactTracking] ❌ Error en tracking ##{tracking_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
  end

  private

  def generate_message(tracking, template_content = nil)
    # Intentar generar mensaje con IA si está disponible
    if tracking.account.hooks.find_by(app_id: 'openai', status: 'enabled')
      ai_message = generate_ai_message(tracking, template_content)
      return "#{ai_message} #IA" if ai_message.present?
    end

    # ⭐ FALLBACK MEJORADO: SIEMPRE generar mensaje simple, nunca plantilla cruda
    # Esto evita enviar mensajes con "[valor]" o plantillas sin personalizar
    Rails.logger.warn "[ContactTracking] ⚠️ IA no disponible o falló - usando mensaje simple"
    generate_simple_message(tracking)
  end

  def generate_ai_message(tracking, template_content = nil)
    hook = tracking.account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return nil unless hook&.settings&.dig('api_key')

    begin
      require 'net/http'
      require 'json'

      api_key = hook.settings['api_key']

      # proyecto@contacts_notes - incluir nota especial para IA del contacto si existe
      ia_note = tracking.contact.notes.for_ia.first
      contact_profile = ia_note.present? ? ActionController::Base.helpers.strip_tags(ia_note.content) : nil

      # ⭐ PASO 1 — System prompt: contexto permanente del seguimiento (GPT-style)
      # proyecto@ai_agent_assistant: se ensambla en PromptBuilder para que el probador
      # muestre EXACTAMENTE este texto y no una copia que derive.
      system_prompt = AiAgentAssistant::PromptBuilder.scheduled_system(
        tracking, contact_profile: contact_profile
      )

      # ⭐ PASO 1 — Tarea final: el pedido concreto de generar el mensaje
      task_prompt = AiAgentAssistant::PromptBuilder.scheduled_task(
        tracking, template_content: template_content
      )

      # ⭐ PASO 2 — Construir array de mensajes con o sin historial
      messages = [{ role: 'system', content: system_prompt }]

      if GPT_HISTORY_ENABLED
        history = build_conversation_history(tracking)
        messages.concat(history)
        Rails.logger.info "[ContactTracking] 🧠 Modo GPT: #{history.size} mensajes del historial incluidos"
      end

      messages << { role: 'user', content: task_prompt }

      uri = URI('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      # proyecto@ai_agent_assistant: el modelo sale del selector "Modelo de IA" de la
      # integración tracking_bot del inbox, no de una constante.
      request.body = {
        model: AiAgentAssistant::EngineConfig.model_for_tracking(tracking, :scheduled),
        messages: messages,
        max_tokens: AiAgentAssistant::EngineConfig.max_tokens_for(:scheduled),
        temperature: 0.7
      }.to_json

      response = http.request(request)
      response_body = JSON.parse(response.body) rescue {}

      ai_message = response_body.dig('choices', 0, 'message', 'content')&.strip

      if ai_message.present?
        ai_message = ai_message.gsub(/\A["']+|["']+\z/, '').strip
        Rails.logger.info "[ContactTracking] 🤖 Mensaje generado con IA (#{GPT_HISTORY_ENABLED ? 'GPT-mode' : 'standard'})"
        return ai_message
      end
    rescue StandardError => e
      Rails.logger.warn "[ContactTracking] ⚠️ Error generando mensaje con IA: #{e.message}"
    end

    nil
  end

  # ⭐ PASO 2 — Construye el historial de conversación en formato OpenAI messages
  # Retorna [] si no hay conversación o si GPT_HISTORY_ENABLED está desactivado
  def build_conversation_history(tracking)
    return [] unless tracking.conversation_id.present?

    begin
      messages = Message.where(conversation_id: tracking.conversation_id)
                        .where('created_at > ?', tracking.created_at)
                        .where(message_type: [0, 1]) # 0=incoming, 1=outgoing
                        .order(created_at: :asc)
                        .limit(10)
                        .to_a

      return [] if messages.empty?

      messages.filter_map do |msg|
        content = msg.content.to_s.strip
        next if content.blank?

        {
          role: msg.incoming? ? 'user' : 'assistant',
          content: content.truncate(300)
        }
      end
    rescue StandardError => e
      Rails.logger.warn "[ContactTracking] ⚠️ Error construyendo historial GPT: #{e.message}"
      []
    end
  end

  def generate_simple_message(tracking)
    # Extraer tema principal del objetivo (primera línea o primeras palabras)
    topic = tracking.objective.split("\n").first.gsub(/^(seguimiento|dar seguimiento a|verificar|revisar)/i, '').strip

    # Usar nombre del contacto si está disponible
    greeting = tracking.contact.name.present? ? "Hola #{tracking.contact.name}!" : "Hola!"

    messages = [
      "#{greeting} Te escribo para dar seguimiento sobre #{topic}. ¿Cómo te ha ido?",
      "#{greeting} Quería saber cómo vas con #{topic}. ¿Hay algo en lo que pueda ayudarte?",
      "#{greeting} Me gustaría saber si pudiste avanzar con #{topic}. Estoy aquí para apoyarte.",
      "#{greeting} Te contacto para ver cómo va todo con #{topic}. ¿Tienes alguna duda?"
    ]

    # Seleccionar mensaje basado en el intento (para variedad)
    messages[tracking.attempt_count % messages.length]
  end

  def is_whatsapp_channel?(tracking)
    channel_type = tracking.inbox.channel_type.to_s.downcase
    
    whatsapp_types = [
      'channel::whatsapp',
      'channel::whatsappcloud',
      'whatsapp',
      'whatsapp_cloud'
    ]
    
    whatsapp_types.any? { |type| channel_type.include?(type) }
  end

  def whatsapp_window_open?(tracking)
    # ⭐ FIX: Buscar el último mensaje INCOMING del CONTACTO en el INBOX
    # No limitarse a una conversación específica, ya que el cliente puede
    # haber escrito en una conversación diferente a la del tracking

    # Buscar todas las conversaciones del contacto en este inbox
    conversation_ids = Conversation
      .where(contact_id: tracking.contact_id, inbox_id: tracking.inbox_id)
      .pluck(:id)

    if conversation_ids.empty?
      Rails.logger.info "[ContactTracking] ⚠️ No hay conversaciones del contacto - Ventana CERRADA"
      return false
    end

    Rails.logger.info "[ContactTracking] 🔍 Buscando en #{conversation_ids.length} conversación(es) del contacto"

    # Buscar el último mensaje INCOMING del cliente en CUALQUIER conversación
    last_customer_message = Message
      .where(conversation_id: conversation_ids)
      .where(message_type: :incoming)
      .order(created_at: :asc)
      .last

    if last_customer_message
      time_since_last_message = Time.current - last_customer_message.created_at
      window_open = time_since_last_message < 24.hours

      Rails.logger.info "[ContactTracking] 🕐 Último mensaje del cliente: #{last_customer_message.created_at}"
      Rails.logger.info "[ContactTracking] 💬 En conversación: #{last_customer_message.conversation_id}"
      Rails.logger.info "[ContactTracking] ⏱️  Tiempo transcurrido: #{(time_since_last_message / 3600).round(2)} horas"
      Rails.logger.info "[ContactTracking] 🪟 Ventana 24h: #{window_open ? 'ABIERTA ✅' : 'CERRADA ❌'}"

      window_open
    else
      Rails.logger.info "[ContactTracking] ⚠️ No hay mensajes previos del cliente"
      Rails.logger.info "[ContactTracking] 🪟 Ventana: CERRADA (sin historial)"
      false
    end
  end

  def get_template_language(tracking, template_name)
    # Caché en memoria para no consultar cada vez
    @template_languages ||= {}

    return @template_languages[template_name] if @template_languages[template_name]

    begin
      require 'httparty'

      access_token = tracking.inbox.channel.provider_config['api_key']
      business_account_id = tracking.inbox.channel.provider_config['business_account_id']

      url = "https://graph.facebook.com/v21.0/#{business_account_id}/message_templates"
      response = HTTParty.get(url,
        headers: { 'Authorization' => "Bearer #{access_token}" },
        query: { name: template_name, limit: 1 }
      )

      if response.success? && response['data']&.any?
        language = response['data'].first['language']
        @template_languages[template_name] = language
        Rails.logger.info "[ContactTracking] 🌍 Idioma de plantilla '#{template_name}': #{language}"
        language
      else
        Rails.logger.warn "[ContactTracking] ⚠️ No se encontró idioma para '#{template_name}', usando es_MX"
        'es_MX'
      end
    rescue StandardError => e
      Rails.logger.error "[ContactTracking] ❌ Error obteniendo idioma: #{e.message}"
      'es_MX' # Fallback
    end
  end

  def get_template_body_text(tracking, template_name)
    # Buscar la plantilla en las plantillas sincronizadas del canal
    channel = tracking.inbox.channel

    return nil unless channel.respond_to?(:message_templates)
    return nil unless channel.message_templates.is_a?(Array)

    # Buscar la plantilla por nombre
    template = channel.message_templates.find { |t| t['name'] == template_name }
    return nil unless template

    # Extraer el componente BODY
    body_component = template['components']&.find { |c| c['type'] == 'BODY' }
    return nil unless body_component

    # Obtener el texto
    body_text = body_component['text']

    if body_text.present?
      Rails.logger.info "[ContactTracking] 📄 Contenido de plantilla encontrado: #{body_text.truncate(100)}"
      body_text
    else
      Rails.logger.warn "[ContactTracking] ⚠️ Plantilla '#{template_name}' sin texto en BODY"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] ❌ Error obteniendo contenido de plantilla: #{e.message}"
    nil
  end

  def send_whatsapp_template(tracking)
    template_name = tracking.current_template

    unless template_name
      Rails.logger.warn "[ContactTracking] ⚠️ No hay plantilla para intento #{tracking.attempt_count + 1}"
      return send_message_via_chatwoot(tracking, generate_message(tracking))
    end

    Rails.logger.info "[ContactTracking] 📱 Usando plantilla WhatsApp: #{template_name}"

    begin
      conversation = find_or_create_conversation(tracking)
      return false unless conversation

      contact_phone = tracking.contact.phone_number&.gsub(/\D/, '')

      # ⭐ OBTENER IDIOMA Y CONTENIDO DE LA PLANTILLA
      language_code = get_template_language(tracking, template_name)
      template_body = get_template_body_text(tracking, template_name)

      # ⭐ PROCESAR PARÁMETROS AUTOMÁTICAMENTE
      params_processor = Whatsapp::TemplateParamsProcessor.new(tracking, template_name)
      params_result = params_processor.process

      if params_result[:success]
        processed_parameters = params_result[:parameters]
        Rails.logger.info "[ContactTracking] ✅ Parámetros procesados: #{processed_parameters.length}"
      else
        # Si hay errores en los parámetros, registrar pero intentar enviar
        Rails.logger.warn "[ContactTracking] ⚠️ Errores en parámetros: #{params_result[:errors].join(', ')}"
        processed_parameters = params_result[:parameters]

        # Si todos los parámetros están vacíos, marcar error
        if processed_parameters.all? { |p| p[:text].blank? }
          Rails.logger.error "[ContactTracking] ❌ No se pudieron resolver los parámetros de la plantilla"
          tracking.update!(
            last_error: "Plantilla '#{template_name}' requiere parámetros que no se pudieron resolver: #{params_result[:errors].join(', ')}"
          )
          # Intentar con mensaje de texto si la ventana está abierta
          if whatsapp_window_open?(tracking)
            Rails.logger.info "[ContactTracking] 🔄 Fallback a mensaje de texto (ventana abierta)"
            return send_message_via_chatwoot(tracking, generate_message(tracking, template_body))
          end
          return false
        end
      end

      # Generar contenido del mensaje con parámetros reemplazados
      message_content = replace_template_params(template_body, processed_parameters) || "📱 Plantilla: #{template_name}"

      Rails.logger.info "[ContactTracking] 📞 Teléfono contacto: #{contact_phone}"
      Rails.logger.info "[ContactTracking] 🌍 Idioma: #{language_code}"
      Rails.logger.info "[ContactTracking] 📄 Contenido: #{message_content.truncate(100)}"
      Rails.logger.info "[ContactTracking] 🔢 Parámetros: #{processed_parameters.inspect}"

      unless contact_phone
        Rails.logger.error "[ContactTracking] ❌ Contacto sin número de teléfono"
        return false
      end

      # ⭐ PASO 1: ENVIAR PLANTILLA PRIMERO (sin crear mensaje en BD)
      channel = tracking.inbox.channel

      # Crear mensaje temporal solo para enviar (no se guarda en BD)
      temp_message = Message.new(
        conversation: conversation,
        account: tracking.account,
        inbox: tracking.inbox,
        message_type: :outgoing,
        content: message_content
      )

      # Enviar usando el servicio oficial con parámetros procesados
      message_id = channel.send_template(
        temp_message,
        contact_phone,
        {
          name: template_name,
          namespace: nil,
          lang_code: language_code,
          parameters: processed_parameters
        }
      )

      unless message_id.present?
        Rails.logger.error "[ContactTracking] ❌ El servicio no retornó message_id"
        return false
      end

      Rails.logger.info "[ContactTracking] ✅ Plantilla enviada a WhatsApp: #{message_id}"

      # ⭐ PASO 2: AHORA crear el mensaje en BD con source_id YA asignado
      # Así el SendReplyJob verá que ya tiene source_id y NO lo enviará de nuevo
      message = Messages::MessageBuilder.new(
        bot_user(tracking.account),
        conversation,
        {
          content: message_content,
          private: false,
          message_type: :outgoing,
          source_id: message_id,  # ⭐ CLAVE: Ya tiene source_id
          content_attributes: {
            whatsapp_template_name: template_name,
            whatsapp_template_language: language_code
          },
          additional_attributes: {
            template_params: {
              'name' => template_name,
              'namespace' => nil,
              'language' => language_code,
              'processed_params' => {}
            }
          }
        }
      ).perform

      if message.present?
        tracking.update!(
          conversation_id: conversation.id,
          last_message_sent: message_content
        )

        Rails.logger.info "[ContactTracking] ✅ Mensaje creado en BD con source_id: #{message_id}"
        true
      else
        Rails.logger.error "[ContactTracking] ❌ No se pudo crear el mensaje en la BD"
        false
      end

    rescue StandardError => e
      Rails.logger.error "[ContactTracking] ❌ Error con plantilla WhatsApp: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      # Si falla la plantilla, verificar ventana antes de fallback
      if whatsapp_window_open?(tracking)
        Rails.logger.info "[ContactTracking] 🔄 Fallback a mensaje de texto normal (ventana abierta)"
        send_message_via_chatwoot(tracking, generate_message(tracking))
      else
        Rails.logger.error "[ContactTracking] ❌ No se puede hacer fallback (ventana cerrada)"
        false
      end
    end
  end

  def send_message_via_chatwoot(tracking, message_body)
    conversation = find_or_create_conversation(tracking)
    return false unless conversation

    # ⭐ FIX: Para WhatsApp con ventana abierta, enviar DIRECTAMENTE por el canal
    # Esto evita el problema donde una nueva conversación no tiene mensajes incoming
    # y can_reply? retorna false, impidiendo el envío de mensajes de sesión
    if is_whatsapp_channel?(tracking)
      Rails.logger.info "[ContactTracking] 📱 Canal WhatsApp detectado - enviando directamente por canal"
      return send_whatsapp_session_message(tracking, conversation, message_body)
    end

    # Para otros canales, usar el flujo normal
    message = Messages::MessageBuilder.new(
      bot_user(tracking.account),
      conversation,
      {
        content: message_body,
        private: false,
        content_attributes: {
          automation_rule_id: nil
        }
      }
    ).perform

    if message.present?
      Rails.logger.info "[ContactTracking] ✅ Mensaje de texto enviado: ID #{message.id}"

      tracking.update!(
        conversation_id: conversation.id,
        last_message_sent: message_body
      )

      true
    else
      Rails.logger.error "[ContactTracking] ❌ MessageBuilder no retornó mensaje"
      false
    end
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] ❌ Error enviando mensaje: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    false
  end

  # ⭐ NUEVO: Enviar mensaje de sesión WhatsApp directamente (ventana abierta)
  def send_whatsapp_session_message(tracking, conversation, message_body)
    channel = tracking.inbox.channel
    contact_phone = tracking.contact.phone_number&.gsub(/\D/, '')

    unless contact_phone
      Rails.logger.error "[ContactTracking] ❌ Contacto sin número de teléfono"
      return false
    end

    Rails.logger.info "[ContactTracking] 📞 Enviando mensaje de sesión a: #{contact_phone}"

    # Crear mensaje temporal para enviar
    temp_message = Message.new(
      conversation: conversation,
      account: tracking.account,
      inbox: tracking.inbox,
      message_type: :outgoing,
      content: message_body
    )

    # Enviar directamente por el canal
    message_id = channel.send_message(contact_phone, temp_message)

    unless message_id.present?
      Rails.logger.error "[ContactTracking] ❌ El canal no retornó message_id"
      return false
    end

    Rails.logger.info "[ContactTracking] ✅ Mensaje enviado a WhatsApp: #{message_id}"

    # Crear el mensaje en BD con source_id ya asignado (evita doble envío)
    message = Messages::MessageBuilder.new(
      bot_user(tracking.account),
      conversation,
      {
        content: message_body,
        private: false,
        source_id: message_id,  # ⭐ CLAVE: Ya tiene source_id, SendReplyJob lo ignorará
        content_attributes: {
          automation_rule_id: nil
        }
      }
    ).perform

    if message.present?
      tracking.update!(
        conversation_id: conversation.id,
        last_message_sent: message_body
      )
      Rails.logger.info "[ContactTracking] ✅ Mensaje creado en BD con source_id: #{message_id}"
      true
    else
      Rails.logger.error "[ContactTracking] ❌ No se pudo crear el mensaje en la BD"
      false
    end
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] ❌ Error enviando mensaje de sesión: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    false
  end

  def find_or_create_conversation(tracking)
    if tracking.conversation_id.present?
      conversation = Conversation.find_by(id: tracking.conversation_id)
      if conversation
        return conversation if conversation.open?

        # Reabrir la conversación original en lugar de crear una nueva
        conversation.update!(status: :open)
        Rails.logger.info "[ContactTracking] 🔄 Conversación ##{conversation.id} reabierta para envío de seguimiento"
        return conversation
      end
    end

    conversation = Conversation
                   .where(
                     account_id: tracking.account_id,
                     inbox_id: tracking.inbox_id,
                     contact_id: tracking.contact_id,
                     status: [:open, :pending]
                   )
                   .last

    unless conversation
      # Buscar conversación resuelta antes de crear una nueva
      conversation = Conversation
                     .where(
                       account_id: tracking.account_id,
                       inbox_id: tracking.inbox_id,
                       contact_id: tracking.contact_id
                     )
                     .order(created_at: :desc)
                     .first

      if conversation
        conversation.update!(status: :open)
        Rails.logger.info "[ContactTracking] 🔄 Conversación ##{conversation.id} reabierta (sin conversation_id en tracking)"
      else
        conversation = Conversation.create!(
          account_id: tracking.account_id,
          inbox_id: tracking.inbox_id,
          contact_id: tracking.contact_id,
          contact_inbox: find_or_create_contact_inbox(tracking),
          status: :open
        )
        Rails.logger.info "[ContactTracking] 🆕 Nueva conversación creada: ID #{conversation.id}"
      end
    end

    conversation
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] ❌ Error creando conversación: #{e.message}"
    nil
  end

  def find_or_create_contact_inbox(tracking)
    contact_inbox = ContactInbox.find_by(
      contact_id: tracking.contact_id,
      inbox_id: tracking.inbox_id
    )

    unless contact_inbox
      source_id = tracking.contact.phone_number || tracking.contact.email || tracking.contact.identifier

      contact_inbox = ContactInbox.create!(
        contact_id: tracking.contact_id,
        inbox_id: tracking.inbox_id,
        source_id: source_id
      )
      Rails.logger.info "[ContactTracking] 🆕 ContactInbox creado: ID #{contact_inbox.id}"
    end

    contact_inbox
  rescue StandardError => e
    Rails.logger.error "[ContactTracking] ❌ Error con ContactInbox: #{e.message}"
    nil
  end

  def bot_user(account)
    account.users.first ||
      AccountUser.where(account_id: account.id).first&.user ||
      User.first
  end

  # ⭐ Reemplazar parámetros {{1}}, {{2}} en el texto de la plantilla
  def replace_template_params(template_text, parameters)
    return template_text if template_text.blank? || parameters.blank?

    result = template_text.dup
    parameters.each_with_index do |param, index|
      param_num = index + 1
      value = param[:text] || param['text'] || ''
      result = result.gsub("{{#{param_num}}}", value)
    end

    result
  end
end