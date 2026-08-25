# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Command: CommandAgents::Commands::Sigue
# Descripcion: Comando /sigue para crear un ContactTracking desde la conversacion.
#
# Flujo de pasos:
#   select_template    -> Selecciona plantilla del menú numerado
#   ask_phone          -> Pide teléfono o nombre del contacto
#   confirm_contact    -> Selecciona entre múltiples resultados
#   ask_retry_interval -> Intervalo entre reintentos
#   ask_max_attempts   -> Número máximo de intentos (no-Meta)
#   ask_schedule       -> Fecha y hora del primer intento
#   confirm_create     -> Resumen y confirmación final
#
# Uso del agente:
#   /sigue              -> Muestra menú completo de plantillas
#   /sigue <filtro>     -> Filtra plantillas por nombre
#   /cancelar           -> Cancela en cualquier paso
#
# Fecha: 2026-02-19
# ================================================================================

module CommandAgents
  module Commands
    class Sigue < Base
      COMMAND_NAME = 'sigue'

      STEPS = %w[select_template ask_phone confirm_contact confirm_replace_tracking ask_new_contact_name ask_new_contact_phone ask_schedule ask_max_attempts ask_retry_interval confirm_create].freeze

      # ============================================================
      # Inicio del comando /sigue
      # ============================================================
      def start
        # Flujo plantilla (default) — el nombre de plantilla puede venir directo como filtro
        template_name = @args.join(' ').strip.delete('"\'')
        start_template_flow(template_name)
      end

      # ============================================================
      # Procesamiento de respuestas segun el paso actual
      # ============================================================
      def continue
        return cancel_session if cancel_requested?(input)

        case @session.current_step
        when 'select_template'          then handle_select_template
        when 'ask_phone'                then handle_ask_phone
        when 'confirm_contact'          then handle_confirm_contact
        when 'ask_new_contact_name'     then handle_ask_new_contact_name
        when 'ask_new_contact_phone'    then handle_ask_new_contact_phone
        when 'confirm_replace_tracking' then handle_confirm_replace_tracking
        when 'ask_schedule'             then handle_ask_schedule
        when 'ask_max_attempts'         then handle_ask_max_attempts
        when 'ask_retry_interval'       then handle_ask_retry_interval
        when 'confirm_create'           then handle_confirm_create
        else
          Rails.logger.error "[Commands::Sigue] Paso desconocido: #{@session.current_step}"
          cancel_session('Ocurrió un error interno. Intenta de nuevo con /sigue.')
        end
      end

      private

      # ============================================================
      # Paso 1: Buscar contacto por telefono o nombre
      # ============================================================
      def handle_ask_phone
        query = input.strip

        contacts = search_contacts(query)

        if contacts.empty?
          # proyecto@commands_agents: guardar el query como teléfono si es válido (se usará sin pedir de nuevo)
          phone_from_query = normalize_phone(query)
          if phone_from_query
            save_data('new_contact_phone', phone_from_query)
            save_data('contact_phone', phone_from_query)
          end
          save_data('new_contact_mode', true)
          save_data('contact_inbox_id', @inbox.id)
          advance_to('ask_new_contact_name')
          reply(<<~MSG)
            ⚠️ No encontré ningún contacto con *#{query}*.

            Vamos a crearlo. ¿Cuál es el *nombre completo* del contacto?
            _(Escribe /salirsigue si no deseas continuar)_
          MSG
          return
        end

        if contacts.size == 1
          proceed_with_contact(contacts.first)
        else
          # Multiples resultados: mostrar lista numerada
          save_data('contact_candidates', contacts.map { |c| { 'id' => c.id, 'name' => c.name, 'phone' => c.phone_number } })
          advance_to('confirm_contact')

          list = contacts.each_with_index.map do |c, i|
            "#{i + 1}. #{c.name} #{format_phone(c.phone_number)}"
          end.join("\n")

          reply("Encontré #{contacts.size} contactos. ¿Cuál es el correcto?\n\n#{list}\n\nResponde con el número:")
        end
      end

      # ============================================================
      # Paso 2: Confirmar contacto cuando hay multiples resultados
      # ============================================================
      def handle_confirm_contact
        candidates = get_data('contact_candidates') || []
        index = input.to_i - 1

        unless index.between?(0, candidates.size - 1)
          reply("Por favor responde con un número del 1 al #{candidates.size}:")
          return
        end

        contact_data = candidates[index]
        contact = Contact.find(contact_data['id'])
        proceed_with_contact(contact)
      end

      # ============================================================
      # Paso 2b-nuevo: Pedir nombre para contacto nuevo
      # ============================================================
      def handle_ask_new_contact_name
        name = input.strip

        if name.length < 2
          reply("⚠️ El nombre es muy corto. Escribe el nombre completo del contacto:")
          return
        end

        save_data('new_contact_name', name)
        save_data('contact_name', name)  # para mostrar en resumen

        # proyecto@commands_agents: si ya tenemos teléfono del query original, saltar ask_new_contact_phone
        if get_data('new_contact_phone').present?
          advance_to_next_step_after_phone(name)
        else
          advance_to('ask_new_contact_phone')
          reply(<<~MSG)
            ✅ Nombre: *#{name}*

            Ahora escribe el *número de teléfono* del contacto (con código de país, ej: +5219991234567):
          MSG
        end
      end

      # ============================================================
      # Paso 2b-nuevo: Guardar teléfono y continuar flujo (SIN crear aún)
      # El contacto, conversación y tracking se crean juntos al confirmar.
      # ============================================================
      def handle_ask_new_contact_phone
        phone = normalize_phone(input.strip)

        if phone.nil?
          reply("⚠️ El número parece inválido. Escribe mínimo 10 dígitos (ej: 3123099236 o +5213123099236):")
          return
        end

        # proyecto@commands_agents: solo guardar, la creación ocurre al confirmar
        save_data('new_contact_phone', phone)
        save_data('contact_phone', phone)  # para mostrar en resumen
        save_data('new_contact_mode', true)
        save_data('contact_inbox_id', @inbox.id)  # para meta_channel? y validaciones

        template = TrackingTemplate.find_by(id: get_data('template_id'))
        if template&.whatsapp_templates.present? && !meta_channel?
          cancel_session(
            "❌ La plantilla *#{template.name}* contiene plantillas Meta " \
            "pero este inbox no es WhatsApp/Facebook/Instagram."
          )
          return
        end
        advance_to('ask_retry_interval')
        reply("✅ Teléfono: *#{phone}*\n\n¿Cada cuánto reintentar si no hay respuesta?\n_(El intervalo es minutos, horas o días)_")
      end

      # proyecto@commands_agents: avanza al siguiente paso cuando ya tenemos el teléfono guardado
      # (se llama desde handle_ask_new_contact_name cuando el query original era un número válido)
      def advance_to_next_step_after_phone(name)
        phone = get_data('new_contact_phone')
        template = TrackingTemplate.find_by(id: get_data('template_id'))
        if template&.whatsapp_templates.present? && !meta_channel?
          cancel_session(
            "❌ La plantilla *#{template.name}* contiene plantillas Meta " \
            "pero este inbox no es WhatsApp/Facebook/Instagram."
          )
          return
        end
        advance_to('ask_retry_interval')
        reply("✅ Nombre: *#{name}* | Teléfono: *#{phone}*\n\n¿Cada cuánto reintentar si no hay respuesta?\n_(El intervalo es minutos, horas o días)_")
      end

      # ============================================================
      # Paso 2b: Confirmar si reemplaza tracking activo existente
      # ============================================================
      def handle_confirm_replace_tracking
        if %w[si sí yes s].include?(input.downcase.strip)
          # Cancelar tracking existente y continuar
          existing_id = get_data('existing_tracking_id')
          ContactTracking.find_by(id: existing_id)&.cancel!
          Rails.logger.info "[Commands::Sigue] Tracking ##{existing_id} cancelado para reemplazo"
          advance_to('ask_retry_interval')
          reply("✅ Seguimiento anterior cancelado.\n\n¿Cada cuánto reintentar si no hay respuesta?\n_(El intervalo es minutos, horas o días)_")
        else
          cancel_session('De acuerdo. El seguimiento existente no fue modificado.')
        end
      end

      # ============================================================
      # Paso 4: Parsear fecha y pedir confirmacion final
      # ============================================================
      def handle_ask_schedule
        scheduled_at = parse_date(input)

        unless scheduled_at
          reply("⚠️ No pude entender la fecha *\"#{input}\"*.\n\nIntenta con formato: *20/02/2026 10:00* o *mañana 9am*:")
          return
        end

        if scheduled_at <= Time.current
          reply("⚠️ La fecha debe ser futura. Ingresa una fecha posterior a ahora:")
          return
        end

        save_data('scheduled_at', scheduled_at.iso8601)

        advance_to('confirm_create')
        show_template_confirmation_summary
      end

      # ============================================================
      # Paso 5: Crear el ContactTracking y cerrar sesion
      # ============================================================
      def handle_confirm_create
        answer = input.downcase.strip

        if %w[si sí yes s].include?(answer)
          create_tracking_from_template
        elsif %w[no n cancelar cancel].include?(answer)
          cancel_session('Seguimiento cancelado. Puedes iniciar de nuevo con /sigue.')
        else
          # Respuesta ambigua — pedir confirmación explícita sin avanzar ni cancelar
          reply("¿Deseas crear el seguimiento o cancelarlo?\nResponde *si* para confirmar o *no* para cancelar.")
        end
      end

      # ============================================================
      # Helpers privados
      # ============================================================

      # Guarda el contacto seleccionado y verifica si tiene tracking activo.
      # Si tiene tracking activo: avisa y pide confirmacion para reemplazarlo.
      # Si no tiene: avanza directamente a ask_retry_interval.
      # @param contact [Contact]
      def proceed_with_contact(contact)
        save_data('contact_id', contact.id)
        save_data('contact_name', contact.name)
        save_data('contact_phone', contact.phone_number)

        # proyecto@commands_agents: guardar la conversacion e inbox del contacto (no los del agente)
        contact_conv = find_contact_conversation(contact)
        save_data('contact_conversation_id', contact_conv&.id)
        save_data('contact_inbox_id', contact_conv&.inbox_id)

        # proyecto@commands_agents: validar compatibilidad entre plantilla Meta y inbox del contacto
        if get_data('template_mode')
          template = TrackingTemplate.find_by(id: get_data('template_id'))
          if template&.whatsapp_templates.present? && !meta_channel?
            inbox_label = contact_conv&.inbox&.name || 'la bandeja de este contacto'
            cancel_session(
              "❌ La plantilla *#{template.name}* contiene plantillas de WhatsApp/Meta " \
              "pero *#{inbox_label}* no es un canal Meta (WhatsApp, Facebook o Instagram).\n\n" \
              "Usa */sigue* con un contacto cuya bandeja sea de WhatsApp/Facebook/Instagram, " \
              "o elige una plantilla sin plantillas Meta."
            )
            return
          end
        end

        existing = active_tracking_for_contact(contact.id)

        if existing
          save_data('existing_tracking_id', existing.id)
          advance_to('confirm_replace_tracking')
          reply(<<~MSG)
            ✅ Contacto: *#{contact.name}* #{format_phone(contact.phone_number)}

            ⚠️ Este contacto ya tiene un seguimiento activo:
            - *Objetivo:* #{existing.objective.truncate(80)}
            - *Estado:* #{existing.status}
            - *Programado:* #{existing.scheduled_for&.strftime('%d/%m/%Y %H:%M')}

            ¿Deseas cancelarlo y crear uno nuevo? *(si / no)*
          MSG
        else
          advance_to('ask_retry_interval')
          reply("✅ Contacto: *#{contact.name}* #{format_phone(contact.phone_number)}\n\n¿Cada cuánto reintentar si no hay respuesta?\n_(El intervalo es minutos, horas o días)_")
        end
      end

      # ============================================================
      # Paso 5b: Pedir número de intentos
      # ============================================================
      def handle_ask_max_attempts
        raw = input.strip

        # "3" o vacío → default
        max_attempts = raw.blank? ? 3 : raw.to_i

        unless max_attempts.between?(1, 6)
          reply("⚠️ El número debe estar entre 1 y 6. Intenta de nuevo:")
          return
        end

        save_data('max_attempts', max_attempts)

        advance_to('ask_schedule')
        reply("✅ #{max_attempts} intento(s) configurado(s).\n\n¿Para cuándo deseas programar el primer intento?\n_(Ejemplos: \"mañana 10am\", \"20/02/2026 15:00\")_")
      end

      # ============================================================
      # Paso 5c: Pedir intervalo de reintento
      # ============================================================
      def handle_ask_retry_interval
        value, unit = parse_interval(input.strip)

        unless value
          reply("⚠️ No entendí el intervalo. Intenta con: *30 minutos*, *2 horas* o *1 día*:")
          return
        end

        save_data('retry_interval_value', value)
        save_data('retry_interval_unit', unit)

        unit_label = { 'minutes' => 'minuto(s)', 'hours' => 'hora(s)', 'days' => 'día(s)' }[unit]

        if meta_channel?
          advance_to('ask_schedule')
          reply("✅ Intervalo guardado: cada #{value} #{unit_label}.\n\n¿Para cuándo deseas programar el primer intento?\n_(Ejemplos: \"mañana 10am\", \"20/02/2026 15:00\")_")
        else
          advance_to('ask_max_attempts')
          reply("✅ Intervalo guardado: cada #{value} #{unit_label}.\n\n¿Cuántos intentos máximos deseas programar? *(1-6, predeterminado: 3)*")
        end
      end

      # proyecto@commands_agents: genera el complementary_prompt via OpenAI
      # a partir del contexto crudo del agente y el objetivo del seguimiento.
      # Si OpenAI no está disponible, retorna el contexto crudo como fallback.
      def generate_complementary_prompt(objective, raw_context)
        return '' if raw_context.blank?

        hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
        unless hook&.settings&.dig('api_key')
          Rails.logger.warn '[Commands::Sigue] OpenAI no disponible, usando contexto crudo como complementary_prompt'
          return raw_context
        end

        begin
          require 'net/http'
          require 'json'

          prompt = <<~PROMPT
            Eres un asistente que ayuda a redactar instrucciones claras para mensajes de seguimiento al cliente.

            OBJETIVO DEL SEGUIMIENTO: #{objective}

            CONTEXTO PROPORCIONADO POR EL AGENTE:
            #{raw_context}

            TAREA:
            Basándote en el contexto anterior, redacta instrucciones adicionales claras y concisas para la IA que enviará los mensajes de seguimiento. Las instrucciones deben indicar:
            - Qué aspectos específicos mencionar o evitar según la situación del cliente
            - El tono apropiado según el contexto
            - Información clave del contexto que debe reflejarse en el mensaje

            Escribe solo las instrucciones, en español, máximo 3-4 oraciones.
          PROMPT

          uri = URI('https://api.openai.com/v1/chat/completions')
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.read_timeout = 15

          request = Net::HTTP::Post.new(uri)
          request['Authorization'] = "Bearer #{hook.settings['api_key']}"
          request['Content-Type'] = 'application/json'
          request.body = {
            model: 'gpt-4o-mini',
            messages: [{ role: 'user', content: prompt }],
            max_tokens: 250,
            temperature: 0.4
          }.to_json

          response = http.request(request)
          result   = JSON.parse(response.body)
          generated = result.dig('choices', 0, 'message', 'content')&.strip

          if generated.present?
            Rails.logger.info '[Commands::Sigue] complementary_prompt generado con IA'
            generated
          else
            raw_context
          end
        rescue StandardError => e
          Rails.logger.error "[Commands::Sigue] Error generando complementary_prompt: #{e.message}"
          raw_context
        end
      end

      # ============================================================
      # Helper: Parsea texto de intervalo a [value, unit]
      # Retorna nil si no se puede parsear
      # ============================================================
      def parse_interval(text)
        t = text.downcase.strip

        # default / predeterminado
        return [30, 'minutes'] if %w[default predeterminado].include?(t)

        # Quitar prefijos "cada ", "cada una ", "por "
        t = t.sub(/^cada\s+/, '')
        t = t.sub(/^por\s+/, '')

        # "una hora" / "un día" / "un minuto"
        t = t.sub(/^una?\s+/, '1 ')

        # "30 minutos", "2 horas", "1 día", "1 dia", "hora", "día", "minuto"
        if (m = t.match(/^(\d+)?\s*(min(?:uto(?:s)?)?|hour?s?|hora?s?|d[ií]a?s?)$/i))
          val  = (m[1] || '1').to_i
          word = m[2].downcase
          unit = case word
                 when /^min/        then 'minutes'
                 when /^h(our|ora)/ then 'hours'
                 when /^d[ií]/      then 'days'
                 end
          return [val, unit] if unit && val >= 1
        end

        # Solo número → minutos
        if t.match?(/^\d+$/)
          val = t.to_i
          return [val, 'minutes'] if val >= 1
        end

        nil
      end

      # ============================================================
      # MODO PLANTILLA — métodos del flujo default /sigue
      # ============================================================

      # Inicia el flujo con plantilla. Si template_name está vacío muestra menú.
      def start_template_flow(template_name)
        templates = available_templates

        if templates.empty?
          reply("⚠️ No hay plantillas de seguimiento configuradas en esta cuenta. Contacta al administrador para crear plantillas.")
          return
        end

        if template_name.blank? || template_name == '?'
          # Sin filtro → lista completa
          create_session('select_template', { 'template_mode' => true })
          show_template_menu(templates)
        else
          # proyecto@commands_agents: filtrar por nombre y siempre mostrar menu
          filtered = @account.tracking_templates
                              .where('name ILIKE ?', "%#{template_name}%")
                              .ordered.limit(20)

          create_session('select_template', { 'template_mode' => true })

          if filtered.any?
            show_template_menu(filtered, header: "Resultados para *\"#{template_name}\"*:")
          else
            show_template_menu(templates, warning: "No encontré plantillas con *\"#{template_name}\"*. Lista completa:")
          end
        end
      end

      # Maneja la selección de plantilla desde el menú numerado
      def handle_select_template
        candidates = get_data('template_candidates') || []
        index = input.to_i - 1

        unless index.between?(0, candidates.size - 1)
          reply("Por favor responde con un número del 1 al #{candidates.size}:")
          return
        end

        selected = candidates[index]
        save_data('template_id', selected['id'])
        save_data('template_name', selected['name'])
        advance_to('ask_phone')
        reply("✅ Plantilla: *#{selected['name']}*\n\n¿Cuál es el teléfono o nombre del contacto al que deseas dar seguimiento?")
      end

      # Muestra menú numerado de plantillas disponibles
      def show_template_menu(templates, warning: nil, header: nil)
        candidates = templates.map { |t| { 'id' => t.id, 'name' => t.name } }
        save_data('template_candidates', candidates)

        list   = templates.each_with_index.map { |t, i| "#{i + 1}. *#{t.name}*" }.join("\n")
        prefix = if warning
                   "⚠️ #{warning}\n\n"
                 elsif header
                   "🔍 #{header}\n\n"
                 else
                   ''
                 end

        reply(<<~MSG)
          #{prefix}📋 *Plantillas disponibles:*

          #{list}

          Responde con el número de la plantilla que deseas usar:
        MSG
      end

      # Muestra resumen de confirmación en modo plantilla
      def show_template_confirmation_summary
        template_name = get_data('template_name')
        contact_name  = get_data('contact_name')
        int_value     = get_data('retry_interval_value') || 30
        int_unit      = get_data('retry_interval_unit') || 'minutes'
        template      = TrackingTemplate.find(get_data('template_id'))

        # proyecto@commands_agents: mostrar la fecha en la zona horaria del inbox del contacto
        inbox_id     = get_data('contact_inbox_id')
        target_inbox = inbox_id ? Inbox.find_by(id: inbox_id) : @inbox
        tz_name      = target_inbox&.timezone.presence || @inbox.timezone.presence || 'UTC'
        tz           = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone['UTC']
        scheduled_at = Time.parse(get_data('scheduled_at')).in_time_zone(tz)

        # En Meta los intentos los define la plantilla; en otros canales los eligió el agente
        max_attempts = if meta_channel?
                         t_count = template.whatsapp_templates.present? ? template.whatsapp_templates.size : 3
                         [t_count, 6].min
                       else
                         get_data('max_attempts') || 3
                       end
        unit_label     = { 'minutes' => 'min', 'hours' => 'h', 'days' => 'día(s)' }[int_unit]
        templates_line = template.whatsapp_templates.present? \
          ? "📋 Plantillas: #{template.whatsapp_templates.join(', ')}" \
          : "🤖 Mensajes: IA generativa"

        # proyecto@commands_agents: indicar si es contacto nuevo (se creará al confirmar)
        contact_line = if get_data('new_contact_mode')
                         "👤 Contacto *(NUEVO)*: #{contact_name} #{get_data('contact_phone')}"
                       else
                         "👤 Contacto: #{contact_name}"
                       end

        new_contact_note = get_data('new_contact_mode') \
          ? "\n          Al confirmar se creará el contacto, se abrirá la conversación y se programará el seguimiento." \
          : ''

        reply(<<~MSG)
          📋 *Resumen del seguimiento:*

          📌 Plantilla: *#{template_name}*
          #{contact_line}
          🎯 Objetivo: #{template.objective.truncate(100)}
          📅 Primer intento: #{scheduled_at.strftime('%d/%m/%Y a las %H:%M')}
          🔁 Intentos: #{max_attempts}, cada #{int_value} #{unit_label}
          #{templates_line}
          #{new_contact_note}
          ¿Confirmo la creación? *(si / no)*
        MSG
      end

      # Crea el ContactTracking usando datos de la plantilla seleccionada
      def create_tracking_from_template
        template     = TrackingTemplate.find(get_data('template_id'))
        contact_id   = get_data('contact_id')
        scheduled_at = Time.parse(get_data('scheduled_at'))

        # proyecto@commands_agents: guardia de seguridad — plantilla Meta requiere inbox Meta
        if template.whatsapp_templates.present? && !meta_channel?
          @session.cancel!
          reply("❌ No se puede crear el seguimiento: la plantilla *#{template.name}* requiere un canal Meta (WhatsApp/Facebook/Instagram).")
          return
        end

        # En Meta los intentos los define la plantilla; en otros canales los eligió el agente
        max_attempts = if meta_channel?
                         t_count = template.whatsapp_templates.present? ? template.whatsapp_templates.size : 3
                         [t_count, 6].min
                       else
                         get_data('max_attempts') || 3
                       end
        retry_interval_value = get_data('retry_interval_value') || 30
        retry_interval_unit  = get_data('retry_interval_unit') || 'minutes'

        ai_ctx = ["Seguimiento creado por agente #{@agent.name} via /sigue #{template.name}",
                  template.ai_context].compact.reject(&:blank?).join("\n\n")

        # proyecto@commands_agents: PASO 3 — resolver contacto y conversación antes de crear tracking
        resolved = resolve_contact_and_conversation
        return unless resolved

        tracking = ContactTracking.create!(
          account:              @account,
          contact_id:           resolved[:contact_id],
          inbox:                resolved[:inbox],
          conversation:         resolved[:conversation],
          objective:            template.objective,
          scheduled_for:        scheduled_at,
          max_attempts:         max_attempts,
          retry_interval_value: retry_interval_value,
          retry_interval_unit:  retry_interval_unit,
          whatsapp_templates:   template.whatsapp_templates || [],
          ai_context:           ai_ctx,
          # proyecto@commands_agents: si la plantilla tiene complementary_prompt se usa directo;
          # si no, se genera desde el ai_context de la plantilla via IA
          complementary_prompt: template.complementary_prompt.present? \
            ? template.complementary_prompt \
            : generate_complementary_prompt(template.objective, template.ai_context.to_s),
          calendar_integration_ids: template.calendar_integration_ids.is_a?(Array) ? template.calendar_integration_ids : [],
          tracking_template_id: template.id
        )

        @session.complete!

        # proyecto@commands_agents: mostrar fecha en timezone del inbox del contacto
        inbox_id_for_tz  = get_data('contact_inbox_id')
        target_inbox_tz  = inbox_id_for_tz ? Inbox.find_by(id: inbox_id_for_tz) : @inbox
        tz_name_success  = target_inbox_tz&.timezone.presence || @inbox.timezone.presence || 'UTC'
        tz_success       = ActiveSupport::TimeZone[tz_name_success] || ActiveSupport::TimeZone['UTC']
        scheduled_local  = scheduled_at.in_time_zone(tz_success)

        templates_line = tracking.whatsapp_templates.empty? \
          ? "🤖 Mensajes: IA generativa" \
          : "📋 Plantillas: #{tracking.whatsapp_templates.join(', ')}"

        reply(<<~MSG)
          ✅ *Seguimiento creado exitosamente* (ID ##{tracking.id})

          📌 Plantilla: *#{template.name}*
          El sistema iniciará el primer contacto el #{scheduled_local.strftime('%d/%m/%Y a las %H:%M')}.
          #{templates_line}

          Para crear otro seguimiento escribe */sigue*
        MSG

        Rails.logger.info "[Commands::Sigue] Tracking ##{tracking.id} creado desde plantilla #{template.id}"
      rescue ActiveRecord::RecordInvalid => e
        errors = e.record.errors.full_messages.join("\n- ")
        Rails.logger.error "[Commands::Sigue] Validacion fallida (template): #{errors}"
        @session.record_error!(errors)
        reply("❌ No se pudo crear el seguimiento:\n- #{errors}\n\nIntenta de nuevo con /sigue.")
      rescue StandardError => e
        Rails.logger.error "[Commands::Sigue] Error (template): #{e.message}"
        @session.record_error!(e.message)
        reply("❌ Error al crear el seguimiento: #{e.message}")
      end

      # Plantillas disponibles en la cuenta, ordenadas por última actualización
      def available_templates
        @account.tracking_templates.ordered.limit(20)
      end

      # Detecta si el inbox actual es un canal de Meta
      # (WhatsApp, Facebook Page, Instagram)
      META_CHANNEL_TYPES = %w[Channel::Whatsapp Channel::FacebookPage Channel::Instagram].freeze

      def meta_channel?
        # proyecto@commands_agents: usar el inbox del contacto si ya fue seleccionado
        inbox_id     = get_data('contact_inbox_id')
        target_inbox = inbox_id ? Inbox.find_by(id: inbox_id) : @inbox
        META_CHANNEL_TYPES.include?(target_inbox&.channel_type)
      end

      # proyecto@commands_agents: resuelve contacto + conversación + inbox al confirmar.
      # Si es contacto nuevo: crea contacto → abre conversación con nota privada → retorna IDs.
      # Si es contacto existente: retorna los datos guardados en sesión.
      # Retorna hash { contact_id:, conversation:, inbox: } o nil si falla.
      def resolve_contact_and_conversation
        if get_data('new_contact_mode')
          # PASO 1: Crear contacto
          contact = @account.contacts.create!(
            name:         get_data('new_contact_name'),
            phone_number: get_data('new_contact_phone')
          )
          Rails.logger.info "[Commands::Sigue] Contacto creado: ##{contact.id} - #{contact.name}"

          # PASO 2: Abrir conversación con nota privada (proyecto@conversation_private)
          conversation = open_conversation_with_private_note(contact)
          inbox = conversation&.inbox || @inbox

          { contact_id: contact.id, conversation: conversation, inbox: inbox }
        else
          conv_id  = get_data('contact_conversation_id')
          inbox_id = get_data('contact_inbox_id')
          {
            contact_id:   get_data('contact_id'),
            conversation: conv_id  ? Conversation.find_by(id: conv_id)  : @conversation,
            inbox:        inbox_id ? Inbox.find_by(id: inbox_id)        : @inbox
          }
        end
      rescue ActiveRecord::RecordInvalid => e
        errors = e.record.errors.full_messages.join(', ')
        Rails.logger.error "[Commands::Sigue] Error creando contacto: #{errors}"
        @session.record_error!(errors)
        reply("❌ No se pudo crear el contacto: #{errors}\n\nIntenta de nuevo con /sigue.")
        nil
      rescue StandardError => e
        Rails.logger.error "[Commands::Sigue] Error en resolve_contact_and_conversation: #{e.message}"
        @session.record_error!(e.message)
        reply("❌ Error al crear la conversación: #{e.message}\n\nIntenta de nuevo con /sigue.")
        nil
      end

      # proyecto@commands_agents / proyecto@conversation_private
      # Crea una conversación nueva para el contacto en el mismo inbox del agente
      # y agrega una nota privada indicando que fue creado via bot de comandos.
      # proyecto@commands_agents / proyecto@conversation_private
      # Inicia una conversación privada con el contacto nuevo:
      # 1. ContactInboxBuilder genera el source_id correcto según el tipo de canal
      # 2. ConversationBuilder crea la conversación
      # 3. Primer mensaje como nota privada (solo visible para agentes)
      def open_conversation_with_private_note(contact)
        # ContactInboxBuilder genera source_id automáticamente según canal:
        # WhatsApp → teléfono sin "+", Api/WebWidget → UUID, Email → email, etc.
        contact_inbox = ContactInboxBuilder.new(
          contact: contact,
          inbox:   @inbox
        ).perform

        raise StandardError, "No se pudo crear el vínculo contacto-inbox" unless contact_inbox

        # Crear la conversación vinculada al contacto e inbox
        conversation = ConversationBuilder.new(
          params:        ActionController::Parameters.new(assignee_id: @agent.id),
          contact_inbox: contact_inbox
        ).perform

        raise StandardError, "No se pudo crear la conversación" unless conversation

        # Agregar nota privada como primer mensaje (solo visible para agentes)
        Messages::MessageBuilder.new(
          @agent,
          conversation,
          { content: "📋 Seguimiento iniciado por #{@agent.name} via /sigue. Contacto creado en este momento.",
            private: true }
        ).perform

        Rails.logger.info "[Commands::Sigue] Conversación privada ##{conversation.id} creada para contacto ##{contact.id}"
        conversation
      rescue StandardError => e
        Rails.logger.error "[Commands::Sigue] Error creando conversación privada: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}"
        raise e  # propagar para que resolve_contact_and_conversation lo maneje
      end

      # proyecto@commands_agents: encuentra la conversacion mas reciente del contacto
      # @param contact [Contact]
      # @return [Conversation, nil]
      def find_contact_conversation(contact)
        @account.conversations
                .where(contact_id: contact.id)
                .order(last_activity_at: :desc)
                .first
      end

      # Retorna el tracking activo de un contacto si existe, nil si no
      # @param contact_id [Integer]
      # @return [ContactTracking, nil]
      def active_tracking_for_contact(contact_id)
        ContactTracking
          .where(contact_id: contact_id, status: %w[pending scheduled active paused])
          .first
      end

      # Busca contactos en la cuenta por telefono o nombre
      # @param query [String]
      # @return [Array<Contact>]
      def search_contacts(query)
        @account.contacts
                .where(
                  'phone_number ILIKE :q OR name ILIKE :q',
                  q: "%#{query}%"
                )
                .limit(5)
      end

      # Parsea texto de fecha usando Chronic y formatos comunes.
      # proyecto@commands_agents: usa la zona horaria del inbox del contacto
      # para que las fechas sean relativas a su canal, no al servidor.
      # @param text [String]
      # @return [Time, nil]
      # proyecto@commands_agents: parseo directo en español sin dependencia de Chronic.
      # Soporta 24h y 12h, usa la timezone configurada en el inbox del contacto.
      def parse_date(text)
        inbox_id     = get_data('contact_inbox_id')
        target_inbox = inbox_id ? Inbox.find_by(id: inbox_id) : @inbox
        tz_name      = target_inbox&.timezone.presence ||
                       @inbox.timezone.presence ||
                       @account.timezone.presence ||
                       'UTC'
        tz  = ActiveSupport::TimeZone[tz_name] || ActiveSupport::TimeZone['UTC']
        now = Time.current.in_time_zone(tz)
        Rails.logger.info "[Commands::Sigue] parse_date tz=#{tz_name} text=#{text.inspect}"

        t = text.downcase.strip
        t = t.sub(/^para\s+/, '').sub(/^el\s+/, '')

        # ── 1. DD/MM/YYYY HH:MM [am|pm] ───────────────────────────────────────
        if (m = t.match(%r{(\d{1,2})/(\d{1,2})/(\d{4})\s+(?:a\s+las?\s+)?(\d{1,2}):(\d{2})\s*(am|pm)?}i))
          h = parse_hour(m[4].to_i, m[6])
          return tz_build(tz, m[3].to_i, m[2].to_i, m[1].to_i, h, m[5].to_i)
        end

        # ── 2. DD/MM/YYYY (solo fecha → mediodía) ─────────────────────────────
        if (m = t.match(%r{(\d{1,2})/(\d{1,2})/(\d{4})}))
          return tz_build(tz, m[3].to_i, m[2].to_i, m[1].to_i, 12, 0)
        end

        # ── 3. en X minutos / horas / días / semanas ──────────────────────────
        if (m = t.match(/en\s+(\d+)\s+(minutos?|horas?|d[ií]as?|semanas?)/))
          n = m[1].to_i
          unit = case m[2]
                 when /minuto/ then :minutes
                 when /hora/   then :hours
                 when /d[ií]a/ then :days
                 when /semana/ then :weeks
                 end
          return (now + n.send(unit)).utc
        end

        # ── 4. Expresiones relativas + hora ───────────────────────────────────
        # Normalizar "de la tarde/noche" → pm, "de la mañana" → am
        t = t.gsub(/de la (tarde|noche)/, 'pm').gsub(/de la ma[ñn]ana/, 'am')

        # Extraer hora: HH:MM [am|pm] o H [am|pm]
        h, min = extract_time_parts(t)
        return nil if h.nil?

        base = if t.match?(/pasado\s*ma[ñn]ana/)
                 now.to_date + 2
               elsif t.match?(/\bma[ñn]ana\b/)
                 now.to_date + 1
               elsif t.match?(/\bhoy\b/)
                 now.to_date
               else
                 # Solo se dio hora → usar hoy si es futura, si no mañana
                 today_result = tz_build(tz, now.year, now.month, now.day, h, min)
                 return today_result if today_result && today_result > Time.current
                 return tz_build(tz, (now.to_date + 1).year, (now.to_date + 1).month, (now.to_date + 1).day, h, min)
               end

        tz_build(tz, base.year, base.month, base.day, h, min)
      rescue StandardError => e
        Rails.logger.warn "[Commands::Sigue] parse_date error: #{e.message} — input: #{text.inspect}"
        nil
      end

      # Extrae [hora_24h, minutos] de un texto. Soporta HH:MM [am|pm] y H [am|pm].
      def extract_time_parts(text)
        if (m = text.match(/(\d{1,2}):(\d{2})\s*(am|pm)?/i))
          return [parse_hour(m[1].to_i, m[3]), m[2].to_i]
        end
        if (m = text.match(/\b(\d{1,2})\s*(am|pm)\b/i))
          return [parse_hour(m[1].to_i, m[2]), 0]
        end
        nil
      end

      # Convierte hora a 24h según sufijo am/pm (nil = ya viene en 24h)
      def parse_hour(h, ampm)
        return h if ampm.nil? || ampm.empty?
        ampm = ampm.downcase
        if ampm == 'pm' && h < 12
          h + 12
        elsif ampm == 'am' && h == 12
          0
        else
          h
        end
      end

      # Crea un Time en la zona horaria y lo convierte a UTC
      def tz_build(tz, year, month, day, hour, min)
        tz.local(year, month, day, hour, min, 0).utc
      rescue ArgumentError => e
        Rails.logger.warn "[Commands::Sigue] tz_build error: #{e.message}"
        nil
      end

      # Formatea telefono para mostrar, maneja nil
      # @param phone [String, nil]
      def format_phone(phone)
        phone.present? ? "(#{phone})" : ''
      end

      # proyecto@commands_agents: normaliza número de teléfono
      # - Quita espacios, guiones, paréntesis
      # - 10 dígitos → agrega +52
      # - Ya tiene + → respeta tal cual
      # - Retorna nil si el número es inválido (menos de 10 dígitos)
      def normalize_phone(raw)
        digits_only = raw.gsub(/[\s\-().+]/, '')
        return nil if digits_only.length < 10

        if raw.start_with?('+')
          # Ya tiene código de país → respetar
          raw.gsub(/[\s\-()]/, '')
        elsif digits_only.length == 10
          "+52#{digits_only}"
        else
          # Más de 10 dígitos sin + → asumir que ya incluye código de país
          "+#{digits_only}"
        end
      end
    end
  end
end
