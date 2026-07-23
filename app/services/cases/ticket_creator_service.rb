# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Directiva @crear_ticket (intake IA)
# ================================================================================
# Servicio: Cases::TicketCreatorService
# Responsabilidad: al detectar @crear_ticket en el complementary_prompt, crea un
# CaseTicket BIEN FORMADO usando Cases::Ai::Intake (lee la conversación y arma
# título/descripción/clasificación), aplicando además:
#   - Directiva parametrizable:  @crear_ticket(prioridad=alta, tipo=Soporte)
#   - Anti-duplicado (§11.2): si el contacto ya tiene un caso abierto, lo reusa.
#   - Score de riesgo (§11.3): reincidencia + churn suben la prioridad.
#   - Fase 2 (§6): si falta un dato clave, lo pide UNA vez antes de crear.
#   - Degradación: si la IA no está disponible/falla, cae al alta básica de antes.
#
# Retorna true si actuó (creó/reusó ticket o pidió un dato), false si no.
# Ver: docs/vault-tickets/implementacion/Plan-Crear-Ticket-IA.md
#
# Posición en el flujo del job (try_kbase_then_conversational):
#   [1] KnowledgeBaseResponseService  → deflexión (§11.1): si resuelve, no llega aquí
#   [2] Cases::TicketCreatorService   → este servicio
#   [3] generate_and_send_conversational_reply (fallback)
# ================================================================================

class Cases::TicketCreatorService
  DIRECTIVE_RE = /@crear_ticket(?:\(([^)]*)\))?/i

  PRIORITY_ORDER = %w[low medium high urgent].freeze
  # Sinónimos ES → enum, para @crear_ticket(prioridad=…).
  PRIORITY_ALIASES = {
    'baja' => 'low', 'media' => 'medium', 'normal' => 'medium',
    'alta' => 'high', 'urgente' => 'urgent', 'critica' => 'urgent', 'crítica' => 'urgent'
  }.freeze
  # Ventana para "reincidente": nº de tickets del contacto en los últimos N días.
  REINCIDENCE_DAYS = 14
  REINCIDENCE_THRESHOLD = 2
  PENDING_TTL = 1.hour

  def initialize(message, tracking:)
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @conversation = message.conversation
    @contact      = message.conversation.contact
  end

  def create_if_needed
    return false unless directive_present?

    # §11.2 Anti-duplicado: si ya hay un caso abierto del contacto, se reusa.
    existing = orchestrator.find_active_ticket
    if existing
      link_and_confirm_existing(existing)
      return true
    end

    fields = intake_fields # nil = IA no disponible → degradar

    # Fase 2 (§6): faltan datos y aún no preguntamos → pedir UNA vez y esperar.
    # Devolvemos true: el turno YA se atendió (no debe seguir el fallback del job).
    if fields && ask_for_missing_info?(fields['missing_info'])
      request_missing_info(fields['missing_info'])
      return true
    end

    ticket = build_ticket(directive_overrides, fields)
    return false unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_confirmation(ticket)
    true
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error creando ticket: #{e.message}"
    false
  end

  private

  def directive_present?
    @tracking&.complementary_prompt.to_s.match?(DIRECTIVE_RE)
  end

  def orchestrator
    @orchestrator ||= Cases::OrchestratorService.new(
      account: @account, contact: @contact, conversation: @conversation
    )
  end

  # ---------------------------------------------------------------------------
  # Construcción del ticket: intake IA (+ degradación) → create_from_ai.
  # `fields` = salida del intake, o nil si la IA no está disponible.
  # ---------------------------------------------------------------------------
  def build_ticket(overrides, fields)
    # Degradación: sin IA disponible → alta básica de siempre (título recortado).
    return degraded_ticket if fields.nil?

    forced_priority = resolve_forced_priority(overrides, fields)

    orchestrator.create_from_ai(
      message:             @message,
      tracking:            @tracking,
      title:               fields['title'],
      description:         fields['description'],
      priority:           forced_priority,
      case_type_id:        resolve_case_type_id(overrides, fields),
      ticket_kind:         fields['ticket_kind'],
      impact:              fields['impact'],
      urgency:             fields['urgency'],
      affected_service_id: fields['affected_service_id'],
      category_id:         fields['category_id'],
      custom_attributes:   intake_custom_attributes(fields),
      force_priority:      forced_priority.present?
    )
  end

  # Alta básica anterior (sin IA): título recortado + clasificación async.
  def degraded_ticket
    orchestrator.find_or_create_from_message(@message, tracking: @tracking)
  end

  # Llama al intake IA. nil si la cuenta no tiene IA (key) o la clasificación está
  # apagada, o si el LLM falla → el caller degrada.
  def intake_fields
    return nil unless CaseAiConfig.for_account(@account).active?(:classify)

    intake = Cases::Ai::Intake.new(account: @account)
    return nil unless intake.available?

    intake.extract(conversation_text: conversation_text, policy: policy_prompt)
  end

  # ---------------------------------------------------------------------------
  # Directiva parametrizable: @crear_ticket(prioridad=alta, tipo=Soporte)
  # ---------------------------------------------------------------------------
  def directive_overrides
    m = @tracking.complementary_prompt.to_s.match(DIRECTIVE_RE)
    return {} unless m && m[1].present?

    m[1].split(',').each_with_object({}) do |pair, h|
      k, v = pair.split('=', 2).map { |s| s.to_s.strip }
      h[k.downcase] = v if k.present? && v.present?
    end
  end

  # Precedencia de prioridad: directiva > riesgo > (matriz/medium). Devuelve la
  # prioridad FORZADA (string) o nil para dejar que la matriz/impacto decidan.
  def resolve_forced_priority(overrides, fields)
    forced = normalize_priority(overrides['prioridad'])
    return forced if forced.present?

    risk_bumped_priority(fields)
  end

  def normalize_priority(value)
    return nil if value.blank?

    key = value.to_s.strip.downcase
    key = PRIORITY_ALIASES[key] || key
    PRIORITY_ORDER.include?(key) ? key : nil
  end

  # §11.3 Score de riesgo: parte de la prioridad de la matriz (o media) y la sube
  # un nivel si el intake detectó churn o el contacto es reincidente.
  def risk_bumped_priority(fields)
    return nil unless risky?(fields)

    base = Cases::PriorityMatrix.derive(fields['impact'], fields['urgency']) || 'medium'
    bump(base)
  end

  def risky?(fields)
    fields['churn_risk'] == true || reincident?
  end

  def reincident?
    return false unless @contact

    @account.case_tickets
            .where(contact_id: @contact.id)
            .where('created_at >= ?', REINCIDENCE_DAYS.days.ago)
            .count >= REINCIDENCE_THRESHOLD
  end

  def bump(priority, steps: 1)
    i = PRIORITY_ORDER.index(priority) || 1
    PRIORITY_ORDER[[i + steps, PRIORITY_ORDER.size - 1].min]
  end

  # Tipo por nombre desde la directiva (@crear_ticket(tipo=Soporte)); si no, el
  # que infirió el intake.
  def resolve_case_type_id(overrides, fields)
    name = overrides['tipo']
    if name.present?
      id = @account.case_types.where('LOWER(name) = ?', name.downcase).pick(:id)
      return id if id
    end
    fields['case_type_id']
  end

  # Deja rastro del intake en el ticket (para el asesor y auditoría).
  def intake_custom_attributes(fields)
    attrs = {}
    attrs['churn_risk'] = true if fields['churn_risk']
    attrs['ai_intake'] = {
      'confidence'   => fields['confidence'],
      'reasoning'    => fields['reasoning'],
      'missing_info' => fields['missing_info']
    }.compact
    attrs
  end

  # ---------------------------------------------------------------------------
  # Fase 2 (§6): pedir el dato faltante UNA sola vez (estado en Redis, 1 turno).
  # ---------------------------------------------------------------------------
  def ask_for_missing_info?(missing)
    return false if missing.blank?
    return false if Redis::Alfred.get(pending_key).present? # ya preguntamos → crear igual

    true
  end

  def request_missing_info(missing)
    Redis::Alfred.setex(pending_key, '1', PENDING_TTL)
    text = "Para poder levantar tu caso necesito un dato: #{missing.to_sentence}. " \
           '¿Me lo compartes, por favor?'
    deliver(text)
  end

  def pending_key
    "case_intake_pending::#{@conversation.id}"
  end

  # ---------------------------------------------------------------------------
  # Confirmaciones al cliente
  # ---------------------------------------------------------------------------
  def link_and_confirm_existing(ticket)
    ticket.update(conversation: @conversation) if ticket.conversation_id.nil?
    folio = ticket.folio.presence || "##{ticket.id}"
    deliver("Ya tienes el caso #{folio} en curso; sumé tu mensaje a ese caso. " \
            'Un asesor te contactará a la brevedad.')
    ticket.case_events.create!(
      account: @account, event_type: :message_sent, origin: :bot,
      payload: { ticket_id: ticket.id, linked: true }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error vinculando caso existente: #{e.message}"
  end

  def send_confirmation(ticket)
    Redis::Alfred.delete(pending_key) # cierra el ciclo de Fase 2 si lo hubo
    folio = ticket.folio.presence || "##{ticket.id}"
    text  = "Tu caso #{folio} fue registrado. Un asesor te contactará a la brevedad."
    deliver(text)

    ticket.case_events.create!(
      account:    @account,
      event_type: :message_sent,
      origin:     :bot,
      payload:    { content: text, ticket_id: ticket.id }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación: #{e.message}"
  end

  def deliver(text)
    reply = Messages::MessageBuilder.new(
      bot_user, @conversation, { content: text, private: false }
    ).perform
    return if reply.blank?

    reply.content_attributes[:ticket_created] = true
    reply.save!
  end

  # ---------------------------------------------------------------------------
  # Contexto y política para el intake
  # ---------------------------------------------------------------------------
  # Transcripción reciente de la conversación (Cliente/Bot: …) para que el intake
  # tenga contexto, no solo el último mensaje.
  def conversation_text
    msgs = Message.where(conversation_id: @conversation.id)
                  .where(message_type: [0, 1])
                  .order(created_at: :desc)
                  .limit(8)
                  .reverse
    msgs.map do |m|
      who = m.incoming? ? 'Cliente' : 'Bot'
      "#{who}: #{m.content.to_s.strip.truncate(200)}"
    end.join("\n").presence || @message.content.to_s.strip
  rescue StandardError
    @message.content.to_s.strip
  end

  # El prompt complementario como política de negocio, SIN las directivas técnicas
  # (que son instrucciones para el sistema, no reglas para el intake).
  def policy_prompt
    @tracking.complementary_prompt.to_s
             .gsub(DIRECTIVE_RE, '')
             .gsub(/@[a-z_]+(\([^)]*\))?/i, '')
             .strip
             .presence
  end

  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end
end
