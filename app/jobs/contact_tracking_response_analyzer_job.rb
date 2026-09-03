# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar
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
  # proyecto@ai_agent_attachments: máximo de archivos adjuntados por respuesta ({{nombre}})
  MAX_DIRECTIVE_ATTACHMENTS = ENV.fetch('AI_AGENT_MAX_ATTACHMENTS', '5').to_i
  # Directiva de adjunto: {{nombre}} (admite espacios internos: {{ catalogo }}). El nombre
  # referencia un archivo del Agente IA (ai_agent_attachments) por su `name`.
  ATTACHMENT_DIRECTIVE = /\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/

  # ==============================================================================
  # Método Principal
  # ==============================================================================
  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming?
    return unless message_has_content?(message)
    return if already_replied_by_bot?(message)

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

    # [Gestor de Tickets] hook — falla silenciosamente para no romper el bot @tickets_cases
    begin
      ticket = Cases::OrchestratorService.new(
        account: message.account,
        contact: message.conversation.contact,
        conversation: message.conversation
      ).find_active_ticket

      if ticket
        ticket.update_columns(first_response_at: Time.current) if ticket.first_response_at.nil?
        ticket.case_events.create!(
          account: message.account,
          event_type: :message_received,
          origin: :bot,
          payload: { message_id: message.id }
        )
        Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
      end
    rescue StandardError => e
      Rails.logger.error "[GestorTickets] hook error: #{e.message}"
    end

    # [1] Keywords — prioridad máxima, sin IA (solo si hay texto)
    if message.content.present? && defined?(ContactTrackings::KeywordActionService)
      keyword_service = ContactTrackings::KeywordActionService.new(tracking, message.content, 'incoming')
      if keyword_service.call
        Rails.logger.info '[TrackingBot] ⌨️  Acción por keyword ejecutada — skip RouterService'
        return true
      end
    end

    # [2] proyecto@bot_seguimiento_calendar — Detección de elección de slot
    if pending_slot_selection?(tracking)
      Rails.logger.info '[TrackingBot] 📅 PENDING_SLOT detectado → procesando elección de horario'
      return handle_slot_selection(tracking, message)
    end

    # [2b] proyecto@bot_seguimiento_calendar — Esperando el email (opcional) para la cita
    if pending_email_selection?(tracking)
      Rails.logger.info '[TrackingBot] 📧 PENDING_EMAIL detectado → procesando email'
      return handle_pending_email(tracking, message)
    end

    # [3] RouterService — clasifica ruta via IA
    route_result = classify_route(tracking, message)
    route        = route_result[:route]

    replied = case route
              when :rejected
                handle_rejected(tracking, message, route_result[:confidence])
                true
              when :interested
                # proyecto@tickets_cases — en trackings de intake de datos (@crear_ticket),
                # "interested" no es una señal accionable: el cliente pidiendo o dando datos
                # del servicio ES el flujo normal, no algo que amerite pausar y derivar a un
                # humano. El sistema de tickets ya decide cuándo escalar.
                if ticket_directive_present?(tracking)
                  try_kbase_then_conversational(tracking, message, route_result)
                else
                  handle_interested(tracking, message, route_result[:confidence])
                  true
                end
              when :book_appointment
                dispatch_book_appointment(tracking, message, route_result)
                true
              when :reschedule
                handle_reschedule(tracking, message, route_result)
                true
              when :cancel_appointment
                handle_cancel_appointment(tracking, message)
                true
              when :botseller
                if BotSeller::Dispatcher.configured?
                  Rails.logger.info '[TrackingBot] 🤖 Derivando a @botseller'
                  BotSeller::Dispatcher.new(message).dispatch
                  true
                else
                  try_kbase_then_conversational(tracking, message, route_result)
                end
              else # :tracking o :kbase — kbase decide si tiene respuesta
                try_kbase_then_conversational(tracking, message, route_result)
              end

    save_sentiment_analysis(tracking, route_result, message)
    replied
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en tracking ##{tracking.id}: #{e.message}"
    false
  end

  def try_kbase_then_conversational(tracking, message, route_result = nil)
    # proyecto@bot_seguimiento_calendar — si el clasificador YA resolvió una acción de
    # cita, el calendario gana sobre la KBase: "¿hay disponibilidad para mañana?" no es
    # una consulta técnica. Sin llamada extra al LLM: se reusa el route_result.
    if route_result&.dig(:appointment_action).present? && appointment_dispatchable?(tracking)
      Rails.logger.info "[TrackingBot] 📅 Acción de cita ya clasificada (#{route_result[:appointment_action]}) → " \
                        'calendario antes que KBase'
      dispatch_appointment_action(tracking, message, route_result)
      return true
    end

    # @tickets_cases: @estado_ticket — el cliente pregunta por su caso ("¿cuál es
    # mi ticket?"). Va ANTES de @crear_ticket: consultar un caso no abre uno nuevo.
    # También va ANTES de la KBase: agenda y tickets siempre ganan sobre la hoja.
    if Cases::TicketStatusService.new(message, tracking: tracking).answer_if_status_query
      Rails.logger.info '[TrackingBot] 🔎 Estado de ticket respondido via @estado_ticket'
      return true
    end

    # @tickets_cases: si la directiva @crear_ticket está en el prompt, crea ticket y confirma.
    # Con @crear_ticket(fallback=true) el alta se pospone hasta después de la KBase: el foro
    # o la hoja contestan si pueden, y el ticket queda como último recurso.
    # @ruta — la rama del turno se decide UNA vez y se reutiliza para la fuente y para el
    # escalamiento, así el turno paga una sola llamada de clasificación.
    branch = branch_for(tracking, message)
    # Si alguna rama declara su propio escalamiento, manda lo declarado por rama: una
    # rama sin flecha no abre ticket. Si ninguna lo declara, rige la directiva global.
    if branch_escalations?(tracking)
      ticket_directive   = branch&.escalation
      ticket_as_fallback = ticket_directive.present?
    else
      ticket_directive   = nil
      ticket_as_fallback = Cases::TicketCreatorService.fallback?(tracking)
    end
    return true if !ticket_as_fallback && try_create_ticket(tracking, message, route_result, directive: ticket_directive)

    # proyecto@bot_seguimiento_calendar — @agendar_calendar (appointment-aware): el clasificador
    # ve el ESTADO DE LA CITA y decide la acción concreta (consultar/agendar/mover/cancelar). No
    # es "eager": appointment_action es null salvo que el cliente realmente hable de una cita.
    if appointment_dispatchable?(tracking)
      appt = classify_appointment(tracking, message, route_result)
      if appt && appt[:appointment_action]
        Rails.logger.info "[TrackingBot] 📅 @agendar_calendar → acción de cita: #{appt[:appointment_action]}"
        dispatch_appointment_action(tracking, message, appt)
        return true
      end
    end

    # KBase (hoja/foro/doc) va AL FINAL, como último recurso: si el cliente ya tiene
    # un ticket/cita en curso, esas rutas resuelven el turno antes de llegar aquí y
    # la hoja nunca se come la recolección de datos ni la confirmación de agenda.
    if kbase_available?(message, tracking)
      Rails.logger.info '[TrackingBot] 📚 KBase disponible → intentando búsqueda semántica'
      kbase_replied = KnowledgeBaseResponseService.new(message, tracking: tracking, branch: branch).perform
      if kbase_replied
        Rails.logger.info '[TrackingBot] ✅ KBase respondió'
        return true
      end
      Rails.logger.info '[TrackingBot] ⚠️ KBase sin resultados → conversacional'
    end

    # @tickets_cases: @crear_ticket(fallback=true) — la KBase no resolvió el turno, así que
    # ahora sí se ofrece/levanta el caso.
    if ticket_as_fallback && try_create_ticket(tracking, message, route_result, directive: ticket_directive)
      Rails.logger.info '[TrackingBot] 🎫 Ticket como último recurso' \
                        "#{branch ? " (rama #{branch.name})" : ' (fallback=true)'}"
      return true
    end

    generate_and_send_conversational_reply(tracking, message)
  end

  # @tickets_cases — alta de ticket vía @crear_ticket. Devuelve true si el turno quedó
  # atendido: ticket creado, caso abierto reusado o dato faltante solicitado.
  def try_create_ticket(tracking, message, route_result, directive: nil)
    creator = Cases::TicketCreatorService.new(message, tracking: tracking, directive: directive)
    return false unless creator.create_if_needed

    Rails.logger.info "[TrackingBot] 🎫 Ticket via @crear_ticket (outcome: #{creator.outcome})"
    # proyecto@bot_seguimiento_calendar — si el ticket quedó completo (recién creado o ya
    # existía) y hay calendario configurado, seguimos directo a ofrecer disponibilidad en
    # el mismo turno (ETAPA 3), en vez de esperar a que el cliente lo pida en otro mensaje.
    # Mismo comportamiento que ya tenía dispatch_book_appointment cuando el Router detecta
    # appointment_action explícito.
    if %i[created linked_existing].include?(creator.outcome) && appointment_dispatchable?(tracking)
      handle_book_appointment(tracking, message, route_result)
    end
    true
  end

  # @ruta — rama del turno, memorizada por (tracking, message) para no clasificar dos veces.
  def branch_for(tracking, message)
    @branch_cache ||= {}
    key = [tracking.id, message.id]
    return @branch_cache[key] if @branch_cache.key?(key)

    map = ContactTrackings::RouteMap.parse(tracking.complementary_prompt)
    @branch_cache[key] = if map.present?
                           ContactTrackings::BranchClassifierService.new(
                             tracking, message, map, recent_context: get_recent_context(message, 4)
                           ).classify
                         end
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ Clasificación de rama falló: #{e.message}"
    nil
  end

  def branch_escalations?(tracking)
    ContactTrackings::RouteMap.parse(tracking.complementary_prompt).escalations?
  rescue StandardError
    false
  end

  # Gemelo de KnowledgeBaseResponseService#with_branch_tag, para las ramas que se contestan
  # por aqui. La etiqueta final es lo que dispara las automatizaciones, asi que si falta, la
  # automatizacion no corre y nadie se entera. Solo se AGREGA cuando falta: la que puso el
  # modelo se respeta siempre.
  ANY_TAG_RE = /#[a-z0-9_]{3,}/i

  def with_branch_tag(text, tracking, message)
    route = branch_for(tracking, message)
    tag   = route&.hashtag
    return text if tag.blank? || text.blank? || text.match?(ANY_TAG_RE)

    Rails.logger.info "[TrackingBot] 🏷️ Sin etiqueta → se repone la de la rama '#{route.name}': #{tag}"
    "#{text.rstrip}\n\n#{tag}"
  end

  # Gemelo de KnowledgeBaseResponseService#branch_scope_rule, para las ramas SIN fuente
  # (las declaradas con guion), que no pasan por la kbase y se contestan aquí. El prompt
  # del agente trae las instrucciones de todas sus ramas; sin esta línea el modelo las ve
  # todas y vuelve a decidir por su cuenta cuál aplica, pisando lo que ya resolvió el router.
  def branch_scope_rule(tracking, message)
    route = branch_for(tracking, message)
    return '' if route.blank?

    label = [route.name, route.description].compact_blank.join(' — ')
    <<~RULE.chomp
      RAMA YA DECIDIDA PARA ESTE TURNO: #{label}
      El sistema clasificó el mensaje en esa rama. De las instrucciones de arriba aplica
      únicamente las que correspondan a esa rama e ignora las de las otras. No vuelvas a
      clasificar el mensaje ni cambies de rama por tu cuenta.
    RULE
  end

  def appointment_dispatchable?(tracking)
    agendar_calendar_directive?(tracking) && calendar_configured?(tracking)
  end

  # proyecto@bot_seguimiento_calendar — clasificación appointment-aware. Si DETECT_INTENT está
  # activo ya tenemos el route_result (con appointment_action); si no, clasificamos solo para
  # esta decisión, alimentando al LLM con el estado real de la cita.
  def classify_appointment(tracking, message, route_result = nil)
    return route_result if route_result&.key?(:appointment_action)

    key = get_api_key(message.account)&.dig(:key)
    return nil if key.blank?

    ContactTrackings::RouterService.new(
      tracking, message, key,
      appointment_state: appointment_state_summary(tracking, message),
      recent_messages: get_recent_context(message, 4),
      current_date: router_current_date(tracking, message)
    ).classify
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ classify_appointment falló: #{e.message}"
    nil
  end

  # Despacha según la acción de cita resuelta por el LLM. Reutiliza los handlers existentes;
  # cuando el contacto NO tiene cita, "query"/"move" degradan a agendar una nueva.
  def dispatch_appointment_action(tracking, message, appt)
    has_appt = tracking.appointment_event_id.present? && tracking.appointment_at.present?

    case appt[:appointment_action]
    when :query
      has_appt ? inform_existing_appointment(tracking, message) : handle_book_appointment(tracking, message, appt)
    when :move
      has_appt ? handle_reschedule(tracking, message, appt) : handle_book_appointment(tracking, message, appt)
    when :cancel
      handle_cancel_appointment(tracking, message)
    else # :book_new
      handle_book_appointment(tracking, message, appt)
    end
  end

  # proyecto@bot_seguimiento_calendar — resumen legible del estado de la cita para que el LLM
  # (clasificación y redacción) decida con contexto en vez de a ciegas.
  def appointment_state_summary(tracking, message)
    return 'El contacto NO tiene ninguna cita agendada todavía.' unless tracking.appointment_event_id.present? && tracking.appointment_at.present?

    timezone = appointment_timezone(tracking, message)
    "El contacto YA tiene una cita agendada para el #{format_appointment_datetime(tracking.appointment_at, timezone)}."
  end

  # proyecto@bot_seguimiento_calendar — fecha de hoy (zona del agente) para el RouterService.
  # Solo sirve de ancla para fechas de calendario explícitas ("el 30 de junio" → necesita el año):
  # los días de la semana ("el próximo martes") los resuelve Ruby de forma determinística, no el LLM.
  def router_current_date(tracking, message)
    day_names = %w[domingo lunes martes miércoles jueves viernes sábado]
    now = Time.current.in_time_zone(appointment_timezone(tracking, message))
    "Hoy es #{now.strftime('%Y-%m-%d')} (#{day_names[now.wday]})"
  end

  # proyecto@bot_seguimiento_calendar
  def agendar_calendar_directive?(tracking)
    tracking&.complementary_prompt.to_s.match?(/@agendar_calendar\b/i)
  end

  # proyecto@bot_seguimiento_calendar
  def calendar_configured?(tracking)
    (tracking.tracking_template&.calendar_integration_ids.presence || tracking.calendar_integration_ids).present?
  end

  # proyecto@bot_seguimiento_calendar — zona horaria para agendar (slots, hora mostrada,
  # evento). Se ancla a la zona REAL de Google Calendar para que la hora del chat coincida
  # con la que el contacto ve en su agenda. Si no hay calendario/falla la API, cae a la del
  # Agente IA (tracking_template) → la del inbox → default.
  def appointment_timezone(tracking, message)
    google_calendar_timezone(tracking).presence ||
      tracking&.tracking_template&.timezone.presence ||
      message&.conversation&.inbox&.timezone.presence ||
      'America/Mexico_City'
  end

  # proyecto@bot_seguimiento_calendar — lee la zona horaria de la cuenta de Google Calendar
  # vinculada (la que el usuario ve en su calendario) y la cachea 12h en Redis para no pegar
  # a la API en cada mensaje. Devuelve el IANA tz o nil si no hay calendario / falla.
  def google_calendar_timezone(tracking)
    cal_id = appointment_timezone_calendar_id(tracking)
    return nil if cal_id.blank?

    cache_key = "gcal_tz::#{cal_id}"
    cached = Redis::Alfred.get(cache_key)
    return cached if cached.present?

    integration = UserCalendarIntegration.find_by(id: cal_id)
    return nil if integration.nil?

    tz = GoogleCalendarService.new(integration).account_timezone
    Redis::Alfred.setex(cache_key, tz, 12.hours) if tz.present?
    tz
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ google_calendar_timezone falló: #{e.message}"
    nil
  end

  # Agenda de referencia para la zona: la de la cita ya creada, o la primera configurada.
  def appointment_timezone_calendar_id(tracking)
    return nil if tracking.blank?

    tracking.appointment_calendar_id.presence ||
      Array(appointment_calendar_ids(tracking)).first
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
      kbase_available: kbase_available?(message, tracking),
      botseller_available: BotSeller::Dispatcher.configured?,
      recent_messages: get_recent_context(message, 4),
      appointment_state: appointment_state_summary(tracking, message),
      current_date: router_current_date(tracking, message)
    ).classify
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ RouterService falló: #{e.message} → :tracking"
    { route: :tracking, confidence: 1.0, method: 'error' }
  end

  # @ruta — con rutas declaradas basta con que ALGUNA rama tenga su fuente operativa;
  # cuál se usa lo decide el clasificador dentro del servicio. Sin rutas, la de siempre.
  def kbase_available?(message, tracking = nil)
    return false unless tracking.present?

    cp        = tracking.complementary_prompt.to_s
    route_map = ContactTrackings::RouteMap.parse(cp)

    if route_map.present?
      return route_map.routes.any? do |route|
        route.source? && KnowledgeBase::Directives.available?(
          route.directive, account: message.account, inbox_id: message.inbox_id
        )
      end
    end

    KnowledgeBase::Directives.available?(cp, account: message.account, inbox_id: message.inbox_id)
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

  def already_replied_by_bot?(message)
    message.conversation.messages
           .where(message_type: Message.message_types[:outgoing])
           .where('created_at > ?', message.created_at)
           .where("content_attributes->>'sentiment_auto_reply' = 'true'")
           .exists?
  end

  # ==============================================================================
  # Respuesta Conversacional (cuando ruta es :tracking)
  # ==============================================================================
  def generate_and_send_conversational_reply(tracking, message)
    Rails.logger.info "[TrackingBot] 💬 Generando respuesta conversacional para tracking ##{tracking.id}"
    reply_text = generate_conversational_reply(tracking, message)
    return false if reply_text.blank?

    reply_text = with_branch_tag(reply_text, tracking, message)
    reply_text = "#{reply_text}\n\n-TB"
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
      contact_profile = if ia_note.present?
                          "PERFIL DEL CONTACTO: #{ActionController::Base.helpers.strip_tags(ia_note.content)}\n"
                        else
                          ''
                        end

      tracking.reload
      inbox_timezone = appointment_timezone(tracking, message)
      next_contact = tracking.scheduled_for.in_time_zone(inbox_timezone).strftime('%d/%m/%Y a las %H:%M')

      # Si el prompt contiene directivas kbase, no pasarlo al LLM conversacional:
      # el prompt está diseñado para operar con la kbase y GPT lo simula literalmente
      # generando output tipo "CONSULTA GENERADA / DEBUG / RESULTADO RECIBIDO".
      # @ruta — las líneas de configuración se quitan SIEMPRE (nunca deben llegar al
      # modelo ni al cliente). Al evaluarse el blanqueo sobre el texto ya limpio, un
      # agente con rutas conserva su prosa: sus directivas viven dentro de esas líneas.
      cp_raw = ContactTrackings::RouteMap.strip(tracking.complementary_prompt.to_s)
      has_kbase_directive = cp_raw.match?(KnowledgeBase::Directives::CANNED_RE) ||
                            cp_raw.match?(/@buscar_art[ií]culo\b/i) ||
                            cp_raw.match?(/@buscar_foro\([^)]*\)/i) ||
                            cp_raw.match?(/@discourse\b/i)
      # proyecto@bot_seguimiento_calendar — @agendar_calendar no debe filtrarse al LLM conversacional
      clean_cp = has_kbase_directive ? '' : cp_raw.gsub(/@agendar_calendar\b/i, '').strip
      scope_rule = branch_scope_rule(tracking, message)
      clean_cp = "#{clean_cp}\n\n#{scope_rule}" if clean_cp.present? && scope_rule.present?

      system_prompt = <<~SYSTEM.strip
        Eres un asesor de ventas para #{tracking.account.name}.
        Responde como un humano amable y conocedor del tema. NUNCA menciones que eres un bot o sistema automático.

        #{contact_profile}
        OBJETIVO DE LA CONVERSACIÓN: #{tracking.objective}
        ESTADO DE LA CITA: #{appointment_state_summary(tracking, message)} (si el cliente pregunta por su cita, respóndele con esta fecha/hora exacta; no inventes ni ofrezcas horarios nuevos)
        PRÓXIMO CONTACTO PROGRAMADO: #{next_contact} (si el cliente pide reagendar, infórmale amablemente que su próximo contacto ya está programado para esa fecha y que si necesita cambiarlo debe comunicarse con un asesor)
        #{tracking.ai_context.present? ? "BASE DE CONOCIMIENTO:\n#{tracking.ai_context.truncate(800)}\n" : ''}
        #{clean_cp.present? ? "INSTRUCCIONES ADICIONALES:\n#{clean_cp}" : ''}
        #{clean_cp.match?(ATTACHMENT_DIRECTIVE) ? 'ENVÍO DE ARCHIVOS: Para enviar un archivo al cliente, escribe la directiva EXACTA (por ejemplo {{nombre}}) dentro de tu respuesta, tal cual y sin comillas; el sistema la sustituirá por el archivo adjunto. No la describas ni la traduzcas.' : ''}
      SYSTEM

      user_prompt = <<~USER.strip
        #{message_history.present? ? "#{message_history}\n\n" : ''}Responde al siguiente mensaje de #{first_name}:
        "#{message_text_for_ai(message).truncate(300)}"

        Máximo 4 líneas. Tono natural y conversacional.
        No uses prefijos como "Asesor:" o "Bot:". No incluyas comillas al inicio ni al final.
      USER

      reply = call_openai_for_reply(api_key_data[:key], [
                                      { role: 'system', content: system_prompt },
                                      { role: 'user', content: user_prompt }
                                    ], tracking)
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
  def handle_rejected(tracking, message, _confidence)
    Rails.logger.info '[TrackingBot] ❌ REJECTED → Pausando seguimiento'

    reply_text = generate_action_reply(tracking, message, :rejected)
    send_auto_reply(tracking, message, reply_text)
    tracking.disable_auto_retry_mode!
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏸️ [IN] PAUSADO: Cliente rechazó\nMensaje: \"#{message_text_for_ai(message).truncate(100)}\"",
      outcome: 'rejected' # proyecto@contact_tracking: dashboard
    )
    tracking.pause!
    create_private_note(tracking, message, "Cliente rechazó el seguimiento: \"#{message_text_for_ai(message).truncate(100)}\"")
    Rails.logger.info '[TrackingBot] ⏸️ Seguimiento pausado por rechazo del cliente'
  end

  def handle_interested(tracking, message, _confidence)
    Rails.logger.info '[TrackingBot] ✅ INTERESTED → Pausando seguimiento'

    tracking.disable_auto_retry_mode!
    reply_text = generate_action_reply(tracking, message, :interested)
    send_auto_reply(tracking, message, reply_text)
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏸️ [IP] PAUSADO: Cliente mostró interés\nMensaje: \"#{message_text_for_ai(message).truncate(100)}\"\nRequiere atención humana.",
      outcome: 'interested' # proyecto@contact_tracking: dashboard
    )
    tracking.pause!
    notify_admin_interested(tracking, message)
    create_private_note(tracking, message,
                        "⏸️ Seguimiento PAUSADO - ¡Cliente interesado! Requiere atención humana: \"#{message_text_for_ai(message).truncate(100)}\"")
    Rails.logger.info '[TrackingBot] ⏸️ Seguimiento pausado, administrador notificado'
  end

  def handle_reschedule(tracking, message, action_data)
    # Si ya hay una cita agendada en el calendario, "reagendar" significa MOVER la cita
    # (no el recordatorio del seguimiento). Antes esto solo movía scheduled_for y la IA
    # respondía "tu cita fue agendada…" sin tocar el evento de Google Calendar.
    if tracking.appointment_event_id.present?
      Rails.logger.info '[TrackingBot] 📅 RESCHEDULE con cita activa → moviendo la cita en el calendario'
      return handle_move_appointment(tracking, message, action_data)
    end

    handle_followup_reschedule(tracking, message, action_data)
  end

  # Reagenda el recordatorio del seguimiento (scheduled_for). Comportamiento original,
  # usado cuando NO hay una cita de calendario activa.
  def handle_followup_reschedule(tracking, message, action_data)
    Rails.logger.info '[TrackingBot] 📅 RESCHEDULE → Reagendando seguimiento'

    reschedule_data = action_data[:reschedule_data] || {}
    inbox_timezone = appointment_timezone(tracking, message)

    if reschedule_data.empty?
      Rails.logger.info '[TrackingBot] ❓ Sin fecha/hora → solicitando cuándo'
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
      Rails.logger.error '[TrackingBot] ❌ No se pudo reagendar'
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en reschedule: #{e.message}"
    send_auto_reply(tracking, message, generate_action_reply(tracking, message, :general_error))
  end

  # Mueve una cita YA agendada a una nueva fecha/hora: intenta la hora exacta en la
  # misma agenda de la cita; si está ocupada (o el cliente solo dio el día), ofrece
  # horarios cercanos. Reutiliza confirm_and_create_appointment, que con un
  # appointment_event_id existente en la misma agenda hace update_event (mueve, no duplica).
  def handle_move_appointment(tracking, message, action_data)
    reschedule_data = action_data[:reschedule_data] || {}
    return ask_move_when(tracking, message) if reschedule_data.empty?

    cal_ids = appointment_calendar_ids(tracking)
    return handle_followup_reschedule(tracking, message, action_data) if cal_ids.blank?

    timezone = appointment_timezone(tracking, message)

    # Si el cliente dio una HORA concreta, intentamos ese horario exacto (o alternativas si
    # está ocupado). Si solo dio el DÍA, NO asumimos la hora anterior: ofrecemos los horarios
    # disponibles de ese día para que elija.
    if reschedule_move_has_time?(reschedule_data)
      target = move_target_time(tracking, reschedule_data, timezone)
      return if try_move_to_exact_slot(tracking, message, target, cal_ids, timezone)

      offer_move_alternatives(tracking, message, target&.beginning_of_day, cal_ids, timezone)
    else
      day  = calculate_reschedule_datetime(reschedule_data, timezone)
      from = booking_search_anchor(day, reschedule_data[:time_of_day], timezone)
      offer_move_alternatives(tracking, message, from, cal_ids, timezone,
                              intro: '¡Claro! Para ese día tengo estos horarios:')
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error moviendo la cita: #{e.message}"
    send_auto_reply(tracking, message, generate_action_reply(tracking, message, :general_error))
  end

  # ¿El pedido de reagendado trae una HORA concreta? (no solo un día). relative_days o
  # specific_date sin hora = solo día → ofrecemos los horarios disponibles de ese día.
  def reschedule_move_has_time?(reschedule_data)
    reschedule_data[:specific_time].present? ||
      reschedule_data[:relative_minutes].present? ||
      reschedule_data[:relative_hours].present?
  end

  def ask_move_when(tracking, message)
    send_auto_reply(tracking, message, generate_action_reply(tracking, message, :reschedule_ask_when))
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n⏳ ESPERANDO FECHA: Cliente quiere mover su cita pero no indicó cuándo."
    )
  end

  # Intenta mover la cita a la hora exacta pedida, en la misma agenda. Devuelve true si
  # confirmó el movimiento, false si ese horario no estaba libre.
  def try_move_to_exact_slot(tracking, message, target, cal_ids, timezone)
    return false if target.blank?

    same_cal = [tracking.appointment_calendar_id].compact.presence || cal_ids
    slot = slot_service_for(same_cal, tracking, timezone).slot_for(target)
    return false unless slot

    Rails.logger.info "[TrackingBot] 📅 Moviendo cita a #{target} (agenda #{slot[:calendar_integration_id]})"
    confirm_and_create_appointment(tracking, message, slot_payload(slot))
    true
  end

  # Ofrece horarios para mover la cita, anclados a `from` (inicio del día o de la franja pedida).
  # `intro` permite distinguir "ese horario está ocupado" (hora pedida no libre) de "para ese
  # día tengo estos horarios" (el cliente dio solo el día/franja).
  def offer_move_alternatives(tracking, message, from, cal_ids, timezone, intro: nil)
    service = slot_service_for(cal_ids, tracking, timezone)
    alternatives = from ? service.call(from: from) : service.call

    if alternatives.any?
      Rails.logger.info '[TrackingBot] 📅 Ofreciendo horarios para mover la cita'
      intro ||= 'Uy, ese horario no está disponible 😕. Para mover tu cita tengo estos horarios:'
      presentation = slots_presentation_for(tracking)
      alternatives = order_slots_for_presentation(alternatives, presentation)
      reply = "#{intro}\n\n#{format_slots_lines(alternatives, timezone, presentation)}\n\n¿Cuál te viene bien? Respondé con el número."
      offer_slots(tracking, message, alternatives, reply)
    else
      send_auto_reply(tracking, message,
                      'No encontré disponibilidad para mover tu cita 😕. Un asesor te contactará para coordinarla.')
    end
  end

  def appointment_calendar_ids(tracking)
    (tracking.tracking_template&.calendar_integration_ids.presence || tracking.calendar_integration_ids).presence
  end

  def slot_service_for(cal_ids, tracking, timezone, message: nil)
    ContactTrackings::AvailabilitySlotService.new(
      calendar_integration_ids: cal_ids, timezone: timezone,
      slot_duration: tracking.tracking_template&.calendar_event_duration || 30,
      working_hours: working_hours_for(tracking, message),
      booking_calendars: tracking.tracking_template&.booking_calendar_ids || {}
    )
  end

  # proyecto@bot_seguimiento_calendar — horarios del inbox (Opción A). Solo si el inbox los
  # tiene habilitados; si no, devuelve nil y el slot service usa su default (9–18 lun–vie).
  def working_hours_for(tracking, message)
    inbox = message&.conversation&.inbox || tracking&.inbox
    return nil unless inbox&.working_hours_enabled?

    inbox.working_hours
  end

  def slot_payload(slot)
    { 'slot' => slot[:slot].utc.iso8601, 'end_time' => slot[:end_time].utc.iso8601,
      'agent_name' => slot[:agent_name], 'calendar_name' => slot[:calendar_name],
      'cal_id' => slot[:calendar_integration_id], 'gcal' => slot[:google_calendar_id] }
  end

  # Fecha/hora destino para mover la cita. Si el cliente dio una hora explícita, la usa;
  # si solo dio el día (ej. "la próxima semana"), conserva la hora de la cita actual
  # ("mismo día a la misma hora").
  def move_target_time(tracking, reschedule_data, timezone)
    base = calculate_reschedule_datetime(reschedule_data, timezone)
    return base if reschedule_data[:specific_time].present? ||
                   reschedule_data[:relative_minutes].present? ||
                   reschedule_data[:relative_hours].present?
    return base if tracking.appointment_at.blank?

    appt_local = tracking.appointment_at.in_time_zone(timezone)
    base.in_time_zone(timezone).change(hour: appt_local.hour, min: appt_local.min, sec: 0)
  end

  # proyecto@bot_seguimiento_calendar — el cliente quiere una cita pero este Agente IA
  # no tiene calendarios vinculados: no podemos ofrecer horarios automáticamente, así que
  # damos un mensaje claro y escalamos a un asesor para coordinar manualmente.
  def handle_no_calendar_configured(tracking, message)
    Rails.logger.info '[TrackingBot] 📅 Sin calendarios vinculados → escalando a humano para coordinar cita'
    send_auto_reply(tracking, message, generate_action_reply(tracking, message, :book_appointment_no_calendar))
    tracking.disable_auto_retry_mode!
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n📅 [BA] Cliente quiso agendar pero el agente no tiene calendarios vinculados. Requiere atención humana.",
      outcome: 'interested'
    )
    tracking.pause!
    notify_admin_interested(tracking, message)
    create_private_note(tracking, message,
                        '📅 El cliente quiso agendar una cita pero este Agente IA no tiene calendarios de Google ' \
                        'vinculados. Coordinar la cita manualmente. Requiere atención humana.')
  end

  # proyecto@bot_seguimiento_calendar — el Router puede clasificar intención de
  # agendar ANTES de conocer el objeto del servicio (material, ubicaciones, peso).
  # Si la cuenta usa @crear_ticket, los campos obligatorios del caso son la fuente
  # de verdad de "qué necesita el cliente": los pedimos primero y solo ofrecemos
  # horarios cuando ya están completos (o cuando el caso no aplica/ya existe).
  def dispatch_book_appointment(tracking, message, route_result)
    return handle_book_appointment(tracking, message, route_result) unless ticket_directive_present?(tracking)

    creator = Cases::TicketCreatorService.new(message, tracking: tracking)
    creator.create_if_needed
    return if creator.outcome == :asked_missing_fields

    handle_book_appointment(tracking, message, route_result)
  end

  def ticket_directive_present?(tracking)
    Cases::TicketCreatorService::DIRECTIVE_RE.match?(tracking&.complementary_prompt.to_s)
  end

  # ==============================================================================
  # proyecto@bot_seguimiento_calendar
  # Handler: Agendar cita via Google Calendar
  # ==============================================================================
  def handle_book_appointment(tracking, message, appt = nil)
    # Si el contacto YA tiene una cita activa, no ofrezcas slots nuevos: recuérdale la cita
    # existente y ofrécele moverla o cancelarla (responde "ya tenés una cita el X").
    return inform_existing_appointment(tracking, message) if tracking.appointment_event_id.present? && tracking.appointment_at.present?

    Rails.logger.info '[TrackingBot] 📅 BOOK_APPOINTMENT → buscando disponibilidad en calendarios'

    cal_ids = (tracking.tracking_template&.calendar_integration_ids.presence || tracking.calendar_integration_ids).presence

    unless cal_ids.present?
      handle_no_calendar_configured(tracking, message)
      return
    end

    timezone = appointment_timezone(tracking, message)
    service  = slot_service_for(cal_ids, tracking, timezone, message: message)

    # Si el cliente pidió una fecha/hora concreta ("el viernes a las 16:00"), respetala:
    # confirmá ese horario si está libre, o ofrecé alternativas cerca del día pedido. Solo
    # si no pidió nada concreto caemos al comportamiento por defecto (primeros disponibles).
    requested = requested_datetime_for_booking(appt, timezone)
    return if try_book_requested_slot(tracking, message, service, requested)

    slots = if requested
              from = booking_search_anchor(requested[:at], requested[:time_of_day], timezone)
              service.call(from: from)
            else
              service.call
            end

    if slots.empty?
      Rails.logger.info '[TrackingBot] 📅 Sin slots disponibles → fallback :interested'
      reply = generate_action_reply(tracking, message, :book_appointment_no_slots)
      send_auto_reply(tracking, message, reply)
      tracking.disable_auto_retry_mode!
      tracking.update!(
        ai_context: "#{tracking.ai_context}\n\n📅 [BA] Cliente quiso agendar pero no había disponibilidad. Requiere atención humana."
      )
      tracking.pause!
      notify_admin_interested(tracking, message)
      create_private_note(tracking, message,
                          '📅 Cliente quiso agendar una cita pero no había horarios disponibles en el calendario. Requiere atención humana.')
      return
    end

    # Si pidió una hora exacta que estaba ocupada, lo avisamos antes de las alternativas.
    presentation = slots_presentation_for(tracking)
    slots = order_slots_for_presentation(slots, presentation)
    reply = if requested&.dig(:exact)
              "Uy, ese horario no está disponible 😕. Estos son los más cercanos:\n\n" \
                "#{format_slots_lines(slots, timezone, presentation)}\n\n¿Cuál te viene bien? Respondé con el número."
            else
              format_slots_message(slots, timezone, presentation)
            end
    offer_slots(tracking, message, slots, reply)
    Rails.logger.info "[TrackingBot] 📅 #{slots.size} slots enviados al contacto — esperando elección"
  end

  # Convierte el reschedule_data del router (si trae fecha/hora) en { at:, exact: } para la
  # reserva inicial. `exact` es true solo si el cliente dio una HORA concreta.
  def requested_datetime_for_booking(appt, timezone)
    rd = appt.is_a?(Hash) ? appt[:reschedule_data] : nil
    return nil if rd.blank?

    at = calculate_reschedule_datetime(rd, timezone)
    return nil if at.blank?

    { at: at, exact: rd[:specific_time].present?, time_of_day: rd[:time_of_day] }
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ requested_datetime_for_booking falló: #{e.message}"
    nil
  end

  # Inicio de la búsqueda de slots para un día dado, respetando la franja pedida: "tarde"
  # arranca a las 12:00, "noche" a las 18:00, "mañana" (o sin franja) desde el inicio del día.
  # Como el servicio devuelve los primeros disponibles desde aquí, así caen en la franja pedida.
  TIME_OF_DAY_START = { 'afternoon' => 12, 'evening' => 18 }.freeze
  def booking_search_anchor(day, time_of_day, timezone)
    local = day.in_time_zone(timezone)
    hour  = TIME_OF_DAY_START[time_of_day.to_s]
    hour ? local.change(hour: hour, min: 0, sec: 0) : local.beginning_of_day
  end

  # Si el cliente pidió una hora exacta y está libre, la confirma directo (pide email si hace
  # falta) y limpia cualquier estado pendiente. Devuelve true si tomó el horario, false si no.
  def try_book_requested_slot(tracking, message, service, requested)
    return false unless requested&.dig(:exact)

    slot = service.slot_for(requested[:at])
    return false unless slot

    Rails.logger.info "[TrackingBot] 📅 Horario pedido disponible (#{requested[:at]}) → confirmando"
    proceed_with_selected_slot(tracking, message, slot_payload(slot))
    true
  end

  # El contacto pregunta/insiste por una cita pero ya tiene una agendada: en lugar de
  # volver a ofrecer horarios, le recordamos la cita existente y le ofrecemos mover o
  # cancelar (esas rutas las resuelven :reschedule y :cancel_appointment).
  def inform_existing_appointment(tracking, message)
    timezone  = appointment_timezone(tracking, message)
    formatted = format_appointment_datetime(tracking.appointment_at, timezone)
    Rails.logger.info "[TrackingBot] 📅 El contacto ya tiene una cita (#{formatted}) → recordando en vez de re-ofrecer"
    send_auto_reply(
      tracking, message,
      "Ya tenés una cita agendada para el #{formatted}. 📅 Si querés, puedo *moverla* a otro horario o *cancelarla*. ¿Qué preferís?"
    )
  end

  def format_appointment_datetime(at, timezone)
    day_names   = %w[domingo lunes martes miércoles jueves viernes sábado]
    month_names = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
    local = at.in_time_zone(timezone)
    "#{day_names[local.wday]} #{local.day} de #{month_names[local.month - 1]} a las #{local.strftime('%H:%M')}"
  end

  def pending_slot_selection?(tracking)
    tracking.ai_context.to_s.include?('[PENDING_SLOT]')
  end

  def handle_slot_selection(tracking, message)
    slots_json = tracking.ai_context.to_s.scan(/Slots ofrecidos: (\[.*?\])/m).flatten.last
    slots = slots_json ? JSON.parse(slots_json) : []

    if slots.empty?
      Rails.logger.warn '[TrackingBot] 📅 PENDING_SLOT sin slots en ai_context → limpiando estado'
      clear_pending_slot(tracking)
      return false
    end

    text   = message_text_for_ai(message)
    choice = parse_slot_choice(text, slots.size)

    # Un dígito 1-5 dentro de una frase con fecha/hora ("a las 5 de la tarde", "el jueves
    # a las 3") o con una cantidad ("3 toneladas de arena") NO es una elección de slot:
    # es una propuesta u otro dato → negociamos en vez de confirmar a ciegas.
    if choice.nil? || looks_like_datetime_proposal?(text) || looks_like_quantity?(text)
      Rails.logger.info '[TrackingBot] 📅 No es elección de número → intentando negociar fecha/hora'
      return handle_slot_negotiation(tracking, message, slots)
    end

    selected = slots[choice - 1]
    Rails.logger.info "[TrackingBot] 📅 Slot elegido: opción #{choice} — #{selected['slot']}"
    proceed_with_selected_slot(tracking, message, selected)
    true
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en handle_slot_selection: #{e.message}"
    clear_pending_slot(tracking)
    false
  end

  # Si el contacto ya tiene email, confirma directo; si no, pide el email (opcional)
  # para invitarlo al evento. Ambos caminos limpian el estado [PENDING_SLOT].
  def proceed_with_selected_slot(tracking, message, selected)
    if message.sender&.email.present?
      confirm_and_create_appointment(tracking, message, selected)
    else
      prompt_for_email(tracking, message, selected)
    end
  end

  # proyecto@bot_seguimiento_calendar — negociación multi-turno: el cliente, en vez de
  # elegir un número, propone otra fecha/hora. Intentamos interpretarla, verificar
  # disponibilidad y: confirmarla si está libre, ofrecer cercanas si no, o repreguntar.
  def try_kbase_during_negotiation(tracking, message)
    return false unless kbase_available?(message, tracking)
    return false unless KnowledgeBaseResponseService.new(message, tracking: tracking).perform

    Rails.logger.info '[TrackingBot] 📚 KBase respondió durante la negociación de horario'
    true
  end

  def handle_slot_negotiation(tracking, message, current_slots)
    timezone  = appointment_timezone(tracking, message)
    requested = parse_requested_datetime(tracking, message, timezone)

    if requested
      # Bug #4 — si el cliente dio solo una hora ("a las 2pm"), parse_requested_datetime la
      # ancla a hoy/mañana, ignorando que los slots activos (current_slots) son de otra fecha.
      # Sin esto, slot_for podría confirmar la cita en el día equivocado. Anclamos la hora
      # pedida a la fecha del primer slot ofrecido cuando lo calculado cae a ≤ 1 día de hoy.
      if requested[:exact] && current_slots.any?
        days_from_now = (requested[:at].in_time_zone(timezone).to_date - Time.current.in_time_zone(timezone).to_date).to_i
        if days_from_now <= 1
          first_slot_date = Time.parse(current_slots.first['slot']).in_time_zone(timezone)
          requested = requested.merge(
            at: requested[:at].in_time_zone(timezone).change(
              year: first_slot_date.year, month: first_slot_date.month, day: first_slot_date.day
            ).utc
          )
        end
      end

      cal_ids  = (tracking.tracking_template&.calendar_integration_ids.presence || tracking.calendar_integration_ids).presence
      service  = slot_service_for(cal_ids, tracking, timezone, message: message)

      # Si dio fecha Y hora concretas, intentamos confirmar ese horario exacto.
      if requested[:exact]
        slot = service.slot_for(requested[:at])
        if slot
          Rails.logger.info "[TrackingBot] 📅 Horario propuesto disponible (#{requested[:at]}) → confirmando"
          clear_pending_slot(tracking)
          proceed_with_selected_slot(tracking, message, slot_payload(slot))
          return true
        end
      end

      # Hora exacta ocupada, o solo dio el día: ofrecemos horarios cerca de lo pedido.
      alternatives = service.call(from: requested[:at].beginning_of_day)
      if alternatives.any?
        # Bug #5 — si el día pedido no tiene disponibilidad, el servicio devuelve slots del
        # siguiente día hábil. Avisamos explícitamente en vez de mostrarlos sin contexto.
        requested_date     = requested[:at].in_time_zone(timezone).to_date
        first_offered_date = alternatives.first[:slot].in_time_zone(timezone).to_date
        intro = if first_offered_date != requested_date
                  day_name = SLOT_DAY_NAMES[requested_date.wday]
                  "No hay disponibilidad el #{day_name}. Los primeros horarios disponibles son:"
                elsif requested[:exact]
                  'Uy, ese horario no está disponible 😕. Estos son los más cercanos:'
                else
                  '¡Claro! Para ese día tengo estos horarios:'
                end
        Rails.logger.info '[TrackingBot] 📅 Ofreciendo horarios cercanos a lo pedido'
        presentation = slots_presentation_for(tracking)
        alternatives = order_slots_for_presentation(alternatives, presentation)
        reply = "#{intro}\n\n#{format_slots_lines(alternatives, timezone, presentation)}\n\n¿Cuál te viene bien? Respondé con el número."
        offer_slots(tracking, message, alternatives, reply)
        return true
      end
    end

    # Antes de repreguntar a ciegas: si no es fecha ni elección, puede ser una pregunta
    # real sobre lo ofrecido ("¿qué transporte es TP-113?", "¿qué unidad tienen?"). Dejamos
    # que la KBase (hoja/foro) responda sin perder el estado [PENDING_SLOT] — el cliente
    # sigue pudiendo elegir horario después.
    return true if try_kbase_during_negotiation(tracking, message)

    # No pudimos interpretar la fecha/hora (o no hay alternativas): repreguntamos suave,
    # manteniendo el estado [PENDING_SLOT] para que pueda elegir o proponer de nuevo.
    # Bug #6 — re-mostramos los horarios vigentes para que el cliente tenga contexto en vez
    # de pedir "un número" a ciegas. current_slots viene de JSON (claves string / horas ISO),
    # así que lo normalizamos al shape que espera format_slots_lines (claves símbolo / Time).
    Rails.logger.info '[TrackingBot] 📅 Sin fecha interpretable → repreguntando con los horarios'
    display_slots = current_slots.map do |s|
      { slot: Time.parse(s['slot']), end_time: Time.parse(s['end_time']),
        agent_name: s['agent_name'], calendar_name: s['calendar_name'] }
    end
    slots_list = format_slots_lines(display_slots, timezone, slots_presentation_for(tracking))
    send_auto_reply(tracking, message,
                    "Puedo agendarte en alguno de estos horarios 🙂:\n\n#{slots_list}\n\n" \
                    "Respondé con el número (1 al #{current_slots.size}), o decime qué día y a qué hora te acomoda.")
    true
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en handle_slot_negotiation: #{e.message}"
    send_auto_reply(tracking, message,
                    "Respondé con el número del horario (1 al #{current_slots.size}) que prefieras, por favor 🙂.")
    true
  end

  # Extrae (vía IA) una fecha/hora concreta del mensaje del cliente y la convierte a Time
  # en la zona del agente. Devuelve nil si no propone una fecha/hora interpretable.
  def parse_requested_datetime(tracking, message, timezone)
    api_key_data = get_api_key(tracking.account)
    key = api_key_data&.dig(:key)
    return nil if key.blank?

    text  = message_text_for_ai(message).to_s.truncate(200)
    now   = Time.current.in_time_zone(timezone)
    today = "#{now.strftime('%Y-%m-%d')} (#{SLOT_DAY_NAMES[now.wday]})"
    data  = extract_datetime_json(key, today, text, tracking)
    return nil unless data.is_a?(Hash)

    rd = {
      specific_date: data['specific_date'].presence,
      weekday: data['weekday'].presence,
      weeks_ahead: data['weeks_ahead'].presence&.to_i,
      specific_time: data['specific_time'].presence,
      relative_days: data['relative_days'].presence&.to_i
    }.compact
    return nil if rd.except(:weeks_ahead).empty?

    at = calculate_reschedule_datetime(rd, timezone)
    return nil unless at

    { at: at, exact: rd[:specific_time].present? }
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ No se pudo interpretar la fecha pedida: #{e.message}"
    nil
  end

  def extract_datetime_json(api_key, today, text, tracking = nil)
    require 'net/http'
    require 'json'

    prompt = <<~PROMPT
      Hoy es #{today}. El cliente quiere agendar y puede proponer una fecha/hora en su mensaje.
      Devuelve SOLO un JSON:
      {"specific_date": "YYYY-MM-DD" o null, "weekday": 1..7 o null (1=lunes...7=domingo),
       "weeks_ahead": número o null, "specific_time": "HH:MM" (24h) o null, "relative_days": número o null}.
      Si no propone ninguna fecha/hora concreta, deja todo en null.
      Reglas (NO calcules fechas de calendario a mano; el sistema las resuelve):
      - Día de la semana nombrado ("el martes", "para el jueves"): poné "weekday" (1=lunes...7=domingo)
        y dejá "specific_date" en null. "weeks_ahead" SOLO si lo dice explícito ("en dos semanas"=2);
        si no, dejalo null.
      - Fecha de calendario explícita ("el 30 de junio", "5/7"): poné "specific_date" (YYYY-MM-DD).
      Mensaje del cliente: "#{text}"
    PROMPT

    uri               = URI('https://api.openai.com/v1/chat/completions')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 10

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    # proyecto@contact_tracking: modelo y tope desde la config del inbox.
    request.body = {
      model: ContactTrackings::EngineConfig.model_for_tracking(tracking, :datetime),
      messages: [{ role: 'user', content: prompt }],
      max_tokens: ContactTrackings::EngineConfig.max_tokens_for(:datetime),
      temperature: 0,
      response_format: { type: 'json_object' }
    }.to_json

    response = http.request(request)
    content  = JSON.parse(response.body).dig('choices', 0, 'message', 'content')
    content.present? ? JSON.parse(content) : nil
  end

  # Pistas de que el mensaje propone una fecha/hora (y no elige un número de la lista):
  # días, meses, "mañana/hoy/tarde", "a las N", "am/pm" o un "HH:MM".
  DATETIME_PROPOSAL_HINT = /
    \b(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo|
       hoy|mañana|pasado|tarde|noche|mediod[ií]a|
       enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\b
    | \d{1,2}:\d{2}
    | \b[ap]\.?m\.?\b
    | \bla?s?\s+\d{1,2}\b
  /ix

  def looks_like_datetime_proposal?(text)
    text.to_s.match?(DATETIME_PROPOSAL_HINT)
  end

  # Pistas de que un dígito del mensaje es una CANTIDAD (peso, unidades, viajes...) y
  # no la elección de un horario numerado. Sin este guard, "3 toneladas de arena"
  # confirmaba por error el horario #3 (parse_slot_choice solo mira dígitos sueltos).
  QUANTITY_HINT = /
    \d+\s*
    (ton(elad[ao]s?)?|kgs?|kilos?|litros?|cajas?|pallets?|paquetes?|
     piezas?|personas?|unidad(es)?|cami[oó]n(es)?|viajes?|horas?|
     d[ií]as?|metros?|m3|m²|m2)\b
  /ix

  def looks_like_quantity?(text)
    text.to_s.match?(QUANTITY_HINT)
  end

  def parse_slot_choice(text, max)
    # Números escritos como dígito: "1", "2", etc.
    match = text.match(/\b([1-#{max}])\b/)
    return match[1].to_i if match

    # Números escritos en palabras
    word_map = { 'uno' => 1, 'primera' => 1, 'primero' => 1, 'primer' => 1,
                 'dos' => 2, 'segunda' => 2, 'segundo' => 2,
                 'tres' => 3, 'tercera' => 3, 'tercero' => 3,
                 'cuatro' => 4, 'cuarta' => 4, 'cuarto' => 4,
                 'cinco' => 5, 'quinta' => 5, 'quinto' => 5 }
    word_map.each do |word, num|
      return num if text.downcase.include?(word) && num <= max
    end

    nil
  end

  def clear_pending_slot(tracking)
    # Elimina TODOS los bloques [PENDING_SLOT] (cada uno es "header\nSlots ofrecidos: <json una línea>").
    # No depende del separador \n\n entre bloques: la regex anterior consumía ese \n\n y dejaba
    # vivo un segundo bloque adyacente, provocando estados apilados y elección del slot equivocado.
    cleaned = tracking.ai_context.to_s
                      .gsub(/\n*📅 \[PENDING_SLOT\][^\n]*\nSlots ofrecidos: [^\n]*/, '')
                      .strip
    tracking.update_columns(ai_context: cleaned)
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ No se pudo limpiar PENDING_SLOT: #{e.message}"
  end

  # proyecto@bot_seguimiento_calendar — pedir email (opcional) antes de confirmar la cita
  EMAIL_PATTERN     = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  SKIP_EMAIL_WORDS  = /\b(sin\s+(correo|email)|no\s+tengo|no\s+quiero|omitir|no\s+gracias|sin\s+invitaci[oó]n)\b/i

  def pending_email_selection?(tracking)
    tracking.ai_context.to_s.include?('[PENDING_EMAIL]')
  end

  def prompt_for_email(tracking, message, selected_slot)
    send_auto_reply(tracking, message,
                    '¡Perfecto! 📧 ¿A qué correo te envío la invitación de la cita? ' \
                    'Si preferís, escribí "sin correo" y la agendo igual.')
    clear_pending_slot(tracking)
    clear_pending_email(tracking)
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n📧 [PENDING_EMAIL] Esperando email para la cita.\nCita elegida: #{selected_slot.to_json}"
    )
  end

  def handle_pending_email(tracking, message)
    slot_json = tracking.ai_context.to_s.scan(/Cita elegida: (\{.*?\})/m).flatten.last
    selected  = slot_json ? JSON.parse(slot_json) : nil

    if selected.nil?
      Rails.logger.warn '[TrackingBot] 📧 PENDING_EMAIL sin cita en ai_context → limpiando estado'
      clear_pending_email(tracking)
      return false
    end

    text  = message_text_for_ai(message).to_s.strip
    email = text[EMAIL_PATTERN]

    if email
      begin
        message.sender.update!(email: email)
        Rails.logger.info "[TrackingBot] 📧 Email capturado para la cita: #{email}"
      rescue StandardError => e
        Rails.logger.warn "[TrackingBot] ⚠️ No se pudo guardar el email (#{e.message}) → se agenda sin invitado"
      end
    elsif text.match?(SKIP_EMAIL_WORDS) || text.blank?
      Rails.logger.info '[TrackingBot] 📧 Cliente omitió el email → se agenda sin invitado'
    else
      # No es un email ni un "sin correo" claro → repreguntamos sin perder el estado
      send_auto_reply(tracking, message,
                      'No reconocí un correo válido 😅. Escribí tu email (ej: nombre@correo.com) ' \
                      'o "sin correo" para agendar sin invitación.')
      return true
    end

    clear_pending_email(tracking)
    confirm_and_create_appointment(tracking, message, selected)
    true
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en handle_pending_email: #{e.message}"
    clear_pending_email(tracking)
    false
  end

  def clear_pending_email(tracking)
    # Elimina TODOS los bloques [PENDING_EMAIL] ("header\nCita elegida: <json una línea>"),
    # robusto ante bloques adyacentes (mismo problema que clear_pending_slot).
    cleaned = tracking.ai_context.to_s
                      .gsub(/\n*📧 \[PENDING_EMAIL\][^\n]*\nCita elegida: [^\n]*/, '')
                      .strip
    tracking.update_columns(ai_context: cleaned)
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ No se pudo limpiar PENDING_EMAIL: #{e.message}"
  end

  def confirm_and_create_appointment(tracking, message, selected_slot)
    timezone    = appointment_timezone(tracking, message)
    slot_start  = Time.parse(selected_slot['slot'])
    slot_end    = Time.parse(selected_slot['end_time'])
    agent_name  = selected_slot['agent_name']
    cal_id      = selected_slot['cal_id']
    gcal        = selected_slot['gcal'].presence || 'primary'
    contact     = message.sender
    contact_name = contact&.name || 'Cliente'

    event_created, event_id = create_or_move_calendar_event(tracking, message, slot_start, slot_end, cal_id, gcal)

    local_start = slot_start.in_time_zone(timezone)
    local_end   = slot_end.in_time_zone(timezone)
    day_names   = %w[domingo lunes martes miércoles jueves viernes sábado]
    month_names = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
    fecha_texto = "#{day_names[local_start.wday]} #{local_start.day} de #{month_names[local_start.month - 1]}"
    hora_texto  = "#{local_start.strftime('%H:%M')} – #{local_end.strftime('%H:%M')} hs"

    # No confirmar una cita que NO se creó en el calendario: sería una confirmación
    # falsa al cliente. En su lugar escalamos a un asesor humano y NO marcamos el
    # seguimiento como `appointment` (no contaminar el KPI con citas inexistentes).
    unless event_created
      Rails.logger.warn '[TrackingBot] ⚠️ Evento NO creado en Calendar → no se confirma la cita, se escala a humano'
      send_auto_reply(tracking, message,
                      '¡Gracias por elegir un horario! 🙌 Estoy terminando de confirmar tu cita para el ' \
                      "#{fecha_texto} a las #{hora_texto}. Un asesor te confirmará en breve, disculpá la demora. 😊")
      clear_pending_slot(tracking)
      tracking.disable_auto_retry_mode!
      tracking.update!(
        ai_context: "#{tracking.ai_context}\n\n⚠️ [CITA NO CONFIRMADA] El cliente eligió #{fecha_texto} #{hora_texto} con #{agent_name} pero el evento no pudo crearse en Google Calendar. Requiere atención humana."
      )
      tracking.pause!
      create_private_note(tracking, message,
                          "⚠️ El cliente eligió una cita (#{fecha_texto} de #{local_start.year}, #{hora_texto}, #{agent_name}) " \
                          'pero NO se pudo crear el evento en Google Calendar. Confirmar manualmente con el cliente y agendar. Requiere atención humana.')
      notify_admin_interested(tracking, message)
      return
    end

    reply = "✅ ¡Perfecto! Tu cita está agendada para el #{fecha_texto} de #{local_start.year} a las #{hora_texto}.\nTe esperamos. Si necesitás cambiarla, avisanos con anticipación. 😊"
    send_auto_reply(tracking, message, reply)

    clear_pending_slot(tracking)
    tracking.disable_auto_retry_mode!
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n✅ [CITA AGENDADA] #{fecha_texto} #{hora_texto} con #{agent_name}. Evento en Google Calendar: creado.",
      appointment_at: slot_start, # proyecto@contact_tracking: dashboard KPI citas
      outcome: 'appointment',
      appointment_event_id: event_id,        # referencia para mover/cancelar (#2/#3)
      appointment_calendar_id: cal_id,
      appointment_calendar_gid: gcal         # calendario de Google donde quedó el evento
    )
    tracking.pause!

    nota = "📅 Cita agendada con #{contact_name}\n• Fecha: #{fecha_texto} de #{local_start.year}\n• Hora: #{hora_texto}\n• Agente: #{agent_name}\n• Evento en Calendar: ✅ creado"
    create_private_note(tracking, message, nota)
    notify_admin_interested(tracking, message)

    Rails.logger.info '[TrackingBot] ✅ Cita confirmada y seguimiento pausado'
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en confirm_and_create_appointment: #{e.message}"
    send_auto_reply(tracking, message, 'Lo siento, tuve un problema al confirmar la cita. Un asesor te contactará pronto.')
    clear_pending_slot(tracking)
  end

  # Crea el evento en Google Calendar; si el seguimiento YA tiene una cita agendada
  # (appointment_event_id) en la misma agenda, la MUEVE (update_event) en vez de crear
  # una nueva, evitando duplicados. Si la nueva cita cae en otra agenda, crea el evento
  # nuevo y borra el anterior. Devuelve [event_created (bool), event_id (String|nil)].
  def create_or_move_calendar_event(tracking, message, slot_start, slot_end, cal_id, gcal = 'primary')
    integration = UserCalendarIntegration.find_by(id: cal_id)
    return [false, nil] unless integration

    contact      = message.sender
    contact_name = contact&.name || 'Cliente'
    summary      = "Cita con #{contact_name} — #{tracking.objective.truncate(60)}"
    description  = "Contacto: #{contact_name}\nTeléfono: #{contact&.phone_number}\nObjetivo: #{tracking.objective}"
    attendees    = [contact&.email].compact.select(&:present?)
    service      = GoogleCalendarService.new(integration)

    # Solo se MUEVE en el lugar (update) si el evento previo vive en EXACTAMENTE el mismo
    # calendario (misma cuenta y mismo gid). Si cambió de cuenta o de calendario, se crea
    # uno nuevo en `gcal` y se borra el anterior (delete_stale), evitando duplicados.
    existing_event_id = tracking.appointment_event_id
    old_gid           = tracking.appointment_calendar_gid.presence || 'primary'
    if existing_event_id.present? && tracking.appointment_calendar_id == cal_id && old_gid == gcal
      service.update_event(existing_event_id, calendar_id: gcal, summary: summary, description: description,
                                              start_time: slot_start, end_time: slot_end, attendees: attendees)
      Rails.logger.info "[TrackingBot] 📅 Evento movido en Google Calendar (cal: #{gcal}, id: #{existing_event_id}) → #{slot_start}"
      [true, existing_event_id]
    else
      result   = service.create_event(calendar_id: gcal, summary: summary, description: description,
                                      start_time: slot_start, end_time: slot_end, attendees: attendees)
      event_id = result.is_a?(Hash) ? result['id'] : nil
      Rails.logger.info "[TrackingBot] 📅 Evento creado en Google Calendar (cal: #{gcal}) para #{slot_start} (id: #{event_id})"
      delete_stale_appointment_event(tracking, cal_id, gcal)
      [true, event_id]
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error creando/moviendo evento en Google Calendar: #{e.message}"
    [false, nil]
  end

  # Borra (best-effort) el evento de una cita previa que vivía en OTRA agenda, para no
  # dejar un evento duplicado/huérfano cuando la cita se mueve a un calendario distinto.
  def delete_stale_appointment_event(tracking, new_cal_id, new_gid)
    old_event_id = tracking.appointment_event_id
    old_cal_id   = tracking.appointment_calendar_id
    old_gid      = tracking.appointment_calendar_gid.presence || 'primary'
    # Si el evento previo vive en el MISMO calendario que el nuevo, no hay nada que limpiar.
    return if old_event_id.blank? || (old_cal_id == new_cal_id && old_gid == new_gid)

    old_integration = UserCalendarIntegration.find_by(id: old_cal_id)
    return unless old_integration

    GoogleCalendarService.new(old_integration).delete_event(old_event_id, calendar_id: old_gid)
    Rails.logger.info "[TrackingBot] 📅 Evento previo borrado de la agenda anterior (cal: #{old_gid}, id: #{old_event_id})"
  rescue StandardError => e
    Rails.logger.warn "[TrackingBot] ⚠️ No se pudo borrar el evento previo: #{e.message}"
  end

  # proyecto@bot_seguimiento_calendar — cancela una cita YA agendada: borra el evento
  # del calendario y limpia los campos de cita del seguimiento. Si no hay cita activa,
  # se trata como un rechazo normal.
  def handle_cancel_appointment(tracking, message)
    event_id = tracking.appointment_event_id
    if event_id.blank?
      Rails.logger.info '[TrackingBot] 🗑️  CANCEL sin cita activa → tratado como rejected'
      return handle_rejected(tracking, message, 0.9)
    end

    deleted     = false
    integration = UserCalendarIntegration.find_by(id: tracking.appointment_calendar_id)
    if integration
      begin
        GoogleCalendarService.new(integration).delete_event(
          event_id, calendar_id: tracking.appointment_calendar_gid.presence || 'primary'
        )
        deleted = true
        Rails.logger.info "[TrackingBot] 🗑️  Evento cancelado en Google Calendar (id: #{event_id})"
      rescue StandardError => e
        Rails.logger.error "[TrackingBot] ❌ Error cancelando evento en Google Calendar: #{e.message}"
      end
    end

    send_auto_reply(tracking, message,
                    'Listo, cancelé tu cita. 🙌 Si más adelante querés agendar otra, escribime cuando gustes. 😊')

    tracking.disable_auto_retry_mode!
    tracking.update!(
      appointment_at: nil,
      appointment_event_id: nil,
      appointment_calendar_id: nil,
      appointment_calendar_gid: nil,
      outcome: 'cancelled',
      ai_context: "#{tracking.ai_context}\n\n🗑️ [CITA CANCELADA] El cliente canceló su cita. Evento en Calendar: #{deleted ? 'borrado' : 'no se pudo borrar (revisar)'}."
    )

    nota = "🗑️ Cita cancelada por el cliente.\n• Evento en Calendar: #{deleted ? '✅ borrado' : '⚠️ no se pudo borrar, revisar manualmente'}"
    create_private_note(tracking, message, nota)
    notify_admin_interested(tracking, message)
    Rails.logger.info '[TrackingBot] 🗑️  Cita cancelada y seguimiento actualizado'
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error en handle_cancel_appointment: #{e.message}"
    send_auto_reply(tracking, message, 'Lo siento, tuve un problema al cancelar la cita. Un asesor te contactará pronto.')
  end

  SLOT_DAY_NAMES     = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  SLOT_MONTH_NAMES   = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze
  SLOT_NUMBERS       = %w[1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣].freeze
  SLOTS_PRESENTATIONS = %w[detailed by_agent by_calendar simple by_day].freeze

  # proyecto@bot_seguimiento_calendar — formato configurable (en el Agente IA) con el que se
  # listan los horarios. La numeración 1-5 SIEMPRE refleja la posición en `slots`, para que la
  # elección por número del cliente siga mapeando bien sin importar el agrupamiento.
  def slots_presentation_for(tracking)
    value = tracking.tracking_template&.slots_presentation
    SLOTS_PRESENTATIONS.include?(value) ? value : 'detailed'
  end

  def format_slots_lines(slots, timezone, presentation = 'detailed')
    case presentation
    when 'by_agent'    then format_slots_by_agent(slots, timezone)
    when 'by_calendar' then format_slots_by_calendar(slots, timezone)
    when 'simple'      then format_slots_simple(slots, timezone)
    when 'by_day'      then format_slots_by_day(slots, timezone)
    else format_slots_detailed(slots, timezone)
    end
  end

  # Etiqueta de calendario para mostrarle al cliente (p.ej. "Casa"). Si el slot no trae
  # nombre de calendario (legado/None), cae al nombre del agente y por último a "Agenda".
  def slot_calendar_label(slot)
    slot[:calendar_name].presence || slot[:agent_name].presence || 'Agenda'
  end

  # Reordena los slots para que coincidan con el orden en que se MUESTRAN. En los formatos
  # agrupados (por agente / por calendario) los slots de un mismo grupo van juntos; así la
  # numeración se lee 1,2,3… de arriba hacia abajo en vez de saltar (1 y 4 en el mismo grupo).
  # Es imprescindible reordenar el array ANTES de persistirlo: el número que elige el cliente
  # es el índice en el array guardado, así que display y array deben ir en el mismo orden.
  # `group_by` conserva el orden de aparición de las claves y el orden (por hora) dentro de
  # cada grupo. Los formatos no agrupados quedan igual (orden por hora).
  def order_slots_for_presentation(slots, presentation)
    case presentation
    when 'by_agent'    then slots.group_by { |s| s[:agent_name].presence || 'Agenda' }.values.flatten(1)
    when 'by_calendar' then slots.group_by { |s| slot_calendar_label(s) }.values.flatten(1)
    else slots
    end
  end

  # "jueves 25 jun · 09:00 – 10:00 hs"
  def slot_date_range_text(slot, timezone)
    local     = slot[:slot].in_time_zone(timezone)
    local_end = slot[:end_time].in_time_zone(timezone)
    day       = SLOT_DAY_NAMES[local.wday]
    month     = SLOT_MONTH_NAMES[local.month - 1]
    "#{day} #{local.day} #{month} · #{local.strftime('%H:%M')} – #{local_end.strftime('%H:%M')} hs"
  end

  # A) Detallado (default): fecha, rango, zona y profesional en cada línea.
  def format_slots_detailed(slots, timezone)
    tz_label = timezone_label(timezone)
    slots.each_with_index.map do |s, i|
      agent = s[:agent_name].presence || 'Agenda'
      "#{SLOT_NUMBERS[i]} #{slot_date_range_text(s, timezone)} (hora de #{tz_label}) — #{agent}"
    end.join("\n")
  end

  # B) Simple: sin zona ni profesional.
  def format_slots_simple(slots, timezone)
    slots.each_with_index.map do |s, i|
      "#{SLOT_NUMBERS[i]} #{slot_date_range_text(s, timezone)}"
    end.join("\n")
  end

  # E) Agrupado por agenda: encabezado por profesional + zona, sus horarios debajo.
  def format_slots_by_agent(slots, timezone)
    tz_label = timezone_label(timezone)
    grouped  = slots.each_with_index.group_by { |s, _i| s[:agent_name].presence || 'Agenda' }
    grouped.map do |agent, items|
      lines = items.map { |s, i| "   #{SLOT_NUMBERS[i]} #{slot_date_range_text(s, timezone)}" }
      "👤 #{agent} (hora de #{tz_label})\n#{lines.join("\n")}"
    end.join("\n\n")
  end

  # F) Agrupado por calendario: encabezado con el nombre del calendario (p.ej. "Casa") + zona,
  # sus horarios debajo. Útil cuando el negocio organiza las citas por calendario/recurso.
  def format_slots_by_calendar(slots, timezone)
    tz_label = timezone_label(timezone)
    grouped  = slots.each_with_index.group_by { |s, _i| slot_calendar_label(s) }
    grouped.map do |cal, items|
      lines = items.map { |s, i| "   #{SLOT_NUMBERS[i]} #{slot_date_range_text(s, timezone)}" }
      "📅 #{cal} (hora de #{tz_label})\n#{lines.join("\n")}"
    end.join("\n\n")
  end

  # D) Agrupado por día: encabezado por fecha, solo la hora de inicio en cada opción.
  def format_slots_by_day(slots, timezone)
    grouped = slots.each_with_index.group_by { |s, _i| s[:slot].in_time_zone(timezone).to_date }
    grouped.map do |_date, items|
      local  = items.first[0][:slot].in_time_zone(timezone)
      header = "📅 #{SLOT_DAY_NAMES[local.wday]} #{local.day} #{SLOT_MONTH_NAMES[local.month - 1]}"
      opts   = items.map { |s, i| "#{SLOT_NUMBERS[i]} #{s[:slot].in_time_zone(timezone).strftime('%H:%M')}" }
      "#{header}\n   #{opts.join('   ')}"
    end.join("\n\n")
  end

  # proyecto@bot_seguimiento_calendar — nombre amigable de la zona del agente/inbox para
  # mostrarle al contacto. Usa el nombre que ya provee Rails (ActiveSupport::TimeZone);
  # fallback a la ciudad del identificador IANA.
  def timezone_label(timezone)
    tz   = timezone.to_s
    name = ActiveSupport::TimeZone[tz]&.name.presence || tz
    name = name.split('/').last.to_s.tr('_', ' ') if name.include?('/') # IANA → ciudad
    name.presence || 'tu zona'
  end

  def format_slots_message(slots, timezone, presentation = 'detailed')
    "¡Con gusto! 📅 Tenemos los siguientes horarios disponibles:\n\n#{format_slots_lines(slots, timezone,
                                                                                         presentation)}\n\n¿Cuál te viene bien? Respondé con el número de tu preferencia."
  end

  # Envía un mensaje con horarios y deja el seguimiento esperando la elección
  # (estado [PENDING_SLOT] con los slots serializados en ai_context).
  def offer_slots(tracking, message, slots, reply)
    send_auto_reply(tracking, message, reply)
    # Nunca debe haber más de un estado pendiente a la vez: al (re)ofrecer horarios
    # (incluida la negociación), borramos cualquier PENDING_SLOT/PENDING_EMAIL previo
    # antes de escribir el nuevo, para no apilar bloques y elegir el slot equivocado.
    clear_pending_slot(tracking)
    clear_pending_email(tracking)
    # slot_payload incluye `gcal` (el calendario de Google del slot). Es imprescindible:
    # al elegir un número, confirm_and_create_appointment lee `gcal` para crear el evento
    # en ESE calendario. Si se omite, cae a 'primary' y agenda en el calendario equivocado.
    slots_json = slots.map { |s| slot_payload(s) }
    tracking.update!(
      ai_context: "#{tracking.ai_context}\n\n📅 [PENDING_SLOT] Esperando elección de horario.\nSlots ofrecidos: #{slots_json.to_json}"
    )
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
                                    ], tracking)
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
    base = "Cliente: #{first_name}\nObjetivo: #{objective}\n#{behavior.present? ? "Instrucciones: #{behavior}\n" : ''}Mensaje del cliente: \"#{customer_message}\"\n\n"

    case reply_type
    when :rejected
      "#{base}El cliente rechazó el seguimiento. Genera una despedida breve (2-3 líneas) que respete su decisión, confirme que no recibirá más mensajes automáticos y deje la puerta abierta."
    when :interested
      "#{base}El cliente mostró interés. Genera una respuesta breve (2-3 líneas) que confirme con entusiasmo e indique que un asesor lo contactará pronto."
    when :reschedule_success
      formatted_time = extra_data[:formatted_time] || extra_data[:natural_desc] || 'en el momento solicitado'
      "#{base}El seguimiento fue reagendado para: #{formatted_time}. Genera una confirmación breve (1-2 líneas) mencionando la fecha/hora exacta."
    when :reschedule_ask_when
      "#{base}El cliente quiere reagendar pero no indicó cuándo. Pregúntale de forma natural para qué fecha u hora prefiere. Máximo 2 líneas."
    end
  end

  def default_reply(reply_type, extra_data = {})
    case reply_type
    when :rejected
      'Entendido, respetamos completamente tu decisión. 🙏 No recibirás más mensajes automáticos sobre este tema. ¡Gracias por tu tiempo!'
    when :interested
      '¡Excelente! Me alegra saber que te interesa. ✨ Un asesor de nuestro equipo se pondrá en contacto contigo muy pronto.'
    when :reschedule_success
      formatted_time = extra_data[:formatted_time] || extra_data[:natural_desc] || 'en el momento solicitado'
      "✅ ¡Listo! He reagendado tu recordatorio para el #{formatted_time}."
    when :reschedule_ask_when
      'Con gusto te reagendo 📅 ¿Para qué fecha y hora prefieres que te contactemos?'
    when :reschedule_error, :general_error
      'Lo siento, tuve un problema al procesar tu solicitud. Un agente se pondrá en contacto contigo pronto.'
    when :book_appointment_no_slots
      '¡Gracias por tu interés! 😊 En este momento no tenemos horarios disponibles en agenda. Un asesor se pondrá en contacto contigo a la brevedad para coordinar una cita.'
    when :book_appointment_no_calendar
      '¡Con gusto te agendamos! 😊 En este momento no puedo confirmar el horario de forma automática, así que un asesor se pondrá en contacto contigo a la brevedad para coordinar tu cita.'
    end
  end

  # ==============================================================================
  # OpenAI - Llamada unificada
  # ==============================================================================
  def call_openai_for_reply(api_key, messages, tracking = nil)
    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    # proyecto@contact_tracking: modelo y tope desde la config del inbox.
    request.body = {
      model: ContactTrackings::EngineConfig.model_for_tracking(tracking, :conversational),
      messages: messages,
      max_tokens: ContactTrackings::EngineConfig.max_tokens_for(:conversational),
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
      last_intent: route_result&.dig(:route)&.to_s || 'tracking', # proyecto@contact_tracking: dashboard
      last_sentiment_analysis: {
        sentiment: route_result&.dig(:route)&.to_s || 'tracking',
        confidence: route_result&.dig(:confidence) || 1.0,
        method: route_result&.dig(:method) || 'tracking',
        message_content: message_text_for_ai(message).truncate(200),
        analyzed_at: Time.current,
        message_id: message.id
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

    # proyecto@ai_agent_attachments: resuelve {{nombre}} → archivos del Agente IA
    clean_content, attachment_signed_ids = resolve_attachment_directives(tracking, reply_content)
    return if clean_content.blank? && attachment_signed_ids.empty?

    builder_params = { content: clean_content, private: false }
    builder_params[:attachments] = attachment_signed_ids if attachment_signed_ids.any?

    reply_message = Messages::MessageBuilder.new(
      bot_user(tracking.account),
      message.conversation,
      builder_params
    ).perform

    if reply_message.present?
      reply_message.content_attributes[:sentiment_auto_reply] = true
      reply_message.save!
    end
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error enviando respuesta: #{e.message}"
  end

  # proyecto@ai_agent_attachments
  # Extrae las directivas {{nombre}} del texto de la IA, resuelve cada nombre a un
  # archivo del Agente IA (tracking_template) y devuelve [texto_limpio, signed_ids_de_blobs].
  # Reutiliza el blob ActiveStorage existente (sin duplicar almacenamiento) pasando su
  # signed_id a MessageBuilder, que lo trata como adjunto existente.
  def resolve_attachment_directives(tracking, content)
    template = tracking.tracking_template
    names = content.scan(ATTACHMENT_DIRECTIVE).flatten
    return [content, []] if names.blank? || template.nil?

    signed_ids = []
    names.uniq.each do |name|
      break if signed_ids.size >= MAX_DIRECTIVE_ATTACHMENTS

      attachment = template.ai_agent_attachments.where('LOWER(name) = ?', name.downcase).first
      if attachment&.file&.attached?
        signed_ids << attachment.file.blob.signed_id
      else
        Rails.logger.warn "[TrackingBot] 📎 {{#{name}}} no encontrado en Agente IA ##{template.id}"
      end
    end

    # Quita la directiva del texto. {{ }} es autodelimitado, así que no hay extensión colgada.
    clean = content.gsub(ATTACHMENT_DIRECTIVE, '')
                   .gsub(/[ \t]{2,}/, ' ')
                   .gsub(/ +([.,;:!?])/, '\1')
                   .gsub(/\n{3,}/, "\n\n")
                   .strip
    [clean, signed_ids]
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

    Rails.logger.info '[TrackingBot] 📝 Nota privada creada'
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error creando nota privada: #{e.message}"
  end

  def notify_admin_interested(_tracking, message)
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

    Rails.logger.info '[TrackingBot] 🔔 Notificación enviada al administrador'
  rescue StandardError => e
    Rails.logger.error "[TrackingBot] ❌ Error notificando administrador: #{e.message}"
  end

  # ==============================================================================
  # Utilidades
  # ==============================================================================
  # Cada cuenta usa su propia integración OpenAI (sin fallback a ENV global, multi-tenant).
  def get_api_key(account)
    return nil unless account

    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return { key: hook.settings['api_key'], source: 'account_integration' } if hook&.settings&.dig('api_key').present?

    nil
  end

  def get_recent_context(message, limit = 4)
    return '' unless message.conversation_id.present?

    messages = Message.where(conversation_id: message.conversation_id)
                      .where(message_type: [0, 1])
                      .where.not(id: message.id)
                      .reorder(created_at: :desc)
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

      # Día: el weekday (resuelto en Ruby, determinístico) tiene prioridad sobre specific_date.
      date_str = resolve_reschedule_date(reschedule_data, timezone)

      if reschedule_data[:specific_time]
        hour, minute = reschedule_data[:specific_time].split(':').map(&:to_i)
        if date_str
          Time.zone.parse(date_str).change(hour: hour, min: minute, sec: 0)
        else
          target = now.change(hour: hour, min: minute, sec: 0)
          target < now ? target + 1.day : target
        end
      elsif date_str
        Time.zone.parse("#{date_str} 10:00:00")
      else
        1.hour.from_now
      end
    end
  end

  # Resuelve la FECHA (YYYY-MM-DD) del pedido. Si el cliente nombró un día de la semana, lo
  # calcula Ruby (próxima ocurrencia + weeks_ahead), en vez de confiar en la aritmética del LLM.
  # Cae a specific_date (fecha de calendario explícita) si no hay weekday.
  def resolve_reschedule_date(reschedule_data, timezone)
    return weekday_to_date(reschedule_data[:weekday], reschedule_data[:weeks_ahead], timezone)&.iso8601 if reschedule_data[:weekday].present?

    reschedule_data[:specific_date].presence
  end

  # Próxima ocurrencia de un día de semana ISO (1=lunes ... 7=domingo) en la zona del agente.
  # Si hoy ES ese día, devuelve el de la semana siguiente (no hoy). `weeks_ahead` suma semanas.
  def weekday_to_date(weekday_iso, weeks_ahead, timezone)
    wday = weekday_iso.to_i
    return nil unless (1..7).cover?(wday)

    today = Time.current.in_time_zone(timezone).to_date

    if weeks_ahead.to_i.positive?
      # Con weeks_ahead anclamos al lunes de la semana N y sumamos el offset del día pedido.
      # (El camino anterior forzaba days_until=7 cuando hoy era el día pedido y luego sumaba
      #  weeks_ahead*7 encima → doble salto: 14 días en vez de 7.)
      week_start = today.beginning_of_week(:monday) + (weeks_ahead.to_i * 7).days
      day_offset = (wday - 1) % 7 # ISO: 1=lunes→0 ... 7=domingo→6
      week_start + day_offset.days
    else
      days_until = (wday - today.cwday) % 7
      days_until = 7 if days_until.zero?
      today + days_until.days
    end
  end
end
