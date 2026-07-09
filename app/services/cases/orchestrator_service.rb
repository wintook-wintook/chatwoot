# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Servicio: Cases::OrchestratorService
# Responsabilidad: Punto de entrada único para crear o encontrar un CaseTicket.
#
# Dos formas de crear un ticket:
#   - find_or_create_from_message  → automático, desde un mensaje entrante
#   - create_for_manual            → manual, desde el agente en el panel
#
# find_active_ticket → busca un ticket no cerrado/cancelado para el contacto
# ================================================================================

class Cases::OrchestratorService
  def initialize(account:, contact: nil, conversation: nil)
    @account      = account
    @contact      = contact
    @conversation = conversation
  end

  def find_active_ticket
    CaseTicket
      .where(account: @account, contact: @contact)
      .where.not(status: %w[closed cancelled])
      .order(created_at: :desc)
      .first
  end

  def find_or_create_from_message(message, tracking: nil)
    ticket = find_active_ticket
    return ticket if ticket

    ticket = CaseTicket.create!(
      account:          @account,
      contact:          @contact,
      conversation:     @conversation,
      contact_tracking: tracking,
      case_type:        default_case_type,
      origin:           infer_origin(message),
      priority:         :medium,
      assignee_type:    :bot,
      title:            title_from_message(message)
    )
    enqueue_ai_classification(ticket) # @tickets_cases 3B
    ticket
  end

  def create_for_manual(title:, priority: nil, case_type_id: nil, description: nil,
                        ticket_kind: nil, impact: nil, urgency: nil,
                        affected_service_id: nil, category_id: nil, custom_attributes: {},
                        assignee_id: nil, team_id: nil)
    # @tickets_cases — asignación manual al crear (opcional). Resueltos dentro de
    # la cuenta. Si el agente asignó a mano, gana sobre las reglas (skip_assignment).
    assignee = @account.users.find_by(id: assignee_id) if assignee_id.present?
    team     = @account.teams.find_by(id: team_id)     if team_id.present?

    attrs = {
      account:       @account,
      contact:       @contact,
      conversation:  @conversation,
      case_type:     resolve_case_type(case_type_id),
      origin:        :manual,
      assignee:      assignee,
      team:          team,
      assignee_type: assignee ? :agent : (team ? :team : :bot),
      title:         title,
      description:   description,
      # @tickets_cases 2K — valores de los campos personalizados del tipo de caso.
      custom_attributes: custom_attributes || {}
    }
    # priority: si viene vacío y hay impacto+urgencia, lo deriva la matriz ITIL;
    # si no, aplica el default del modelo (medium).
    attrs[:priority]    = priority    if priority.present?
    attrs[:ticket_kind] = ticket_kind if ticket_kind.present?
    attrs[:impact]      = impact      if impact.present?
    attrs[:urgency]     = urgency     if urgency.present?
    # Resueltos dentro del scope de la cuenta (evita vincular registros de otra cuenta).
    attrs[:affected_service_id] = @account.case_services.where(id: affected_service_id).pick(:id) if affected_service_id.present?
    attrs[:category_id]         = @account.case_categories.where(id: category_id).pick(:id)        if category_id.present?

    ticket = CaseTicket.create!(attrs)
    # Asignación manual presente → las reglas no reasignan (sí enriquecen lo demás).
    Cases::RuleEngineService.new(ticket, skip_assignment: assignee.present? || team.present?).evaluate!
    enqueue_ai_classification(ticket) # @tickets_cases 3B
    ticket
  end

  # @tickets_cases Fase C — ticket interno (agente→agente, sin contacto).
  # requester = agente solicitante; assignee = agente que lo atenderá (opcional).
  # No encola clasificación IA (no hay mensaje de cliente que clasificar).
  def create_internal(requester:, title:, assignee: nil, team: nil, priority: nil, case_type_id: nil,
                      description: nil, ticket_kind: nil, impact: nil, urgency: nil,
                      affected_service_id: nil, category_id: nil, custom_attributes: {})
    attrs = {
      account:       @account,
      contact:       nil,
      requester:     requester,
      case_type:     resolve_case_type(case_type_id),
      origin:        :internal,
      assignee:      assignee,
      team:          team,
      assignee_type: assignee ? :agent : (team ? :team : :bot),
      title:         title,
      description:   description,
      custom_attributes: custom_attributes || {}
    }
    # priority: si viene vacío y hay impacto+urgencia, lo deriva la matriz ITIL;
    # si no, aplica el default del modelo (medium).
    attrs[:priority]    = priority    if priority.present?
    attrs[:ticket_kind] = ticket_kind if ticket_kind.present?
    attrs[:impact]      = impact      if impact.present?
    attrs[:urgency]     = urgency     if urgency.present?
    # Resueltos dentro del scope de la cuenta (evita vincular registros de otra cuenta).
    attrs[:affected_service_id] = @account.case_services.where(id: affected_service_id).pick(:id) if affected_service_id.present?
    attrs[:category_id]         = @account.case_categories.where(id: category_id).pick(:id)        if category_id.present?

    ticket = CaseTicket.create!(attrs)
    # Asignación manual presente (agente/equipo) → las reglas no reasignan.
    Cases::RuleEngineService.new(ticket, skip_assignment: assignee.present? || team.present?).evaluate!
    ticket
  end

  private

  # @tickets_cases 3B — encola la clasificación IA si la cuenta la tiene activa
  # (off/suggest/auto). El job se autoprotege; corre en background sin bloquear.
  def enqueue_ai_classification(ticket)
    return unless CaseAiConfig.for_account(@account).active?(:classify)

    Cases::Ai::ClassifyJob.perform_later(ticket.id)
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] enqueue ai classify: #{e.message}")
  end

  # Tipo de caso por defecto de la cuenta (el primero por posición).
  # Garantiza que la cuenta tenga sus tipos por defecto creados.
  def default_case_type
    CaseType.ensure_defaults_for(@account).first
  end

  def resolve_case_type(case_type_id)
    return default_case_type if case_type_id.blank?

    @account.case_types.find_by(id: case_type_id) || default_case_type
  end

  def infer_origin(message)
    case message.inbox&.channel_type
    when 'Channel::Whatsapp'  then :whatsapp
    when 'Channel::WebWidget' then :web
    when 'Channel::Email'     then :email
    else :bot
    end
  end

  def title_from_message(message)
    message.content.to_s.strip.truncate(100).presence || 'Consulta sin título'
  end
end
