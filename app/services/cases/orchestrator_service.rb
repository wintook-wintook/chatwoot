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
  def initialize(account:, contact:, conversation: nil)
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

    CaseTicket.create!(
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
  end

  def create_for_manual(title:, priority:, case_type_id: nil, description: nil)
    ticket = CaseTicket.create!(
      account:       @account,
      contact:       @contact,
      conversation:  @conversation,
      case_type:     resolve_case_type(case_type_id),
      origin:        :manual,
      priority:      priority,
      assignee_type: :agent,
      title:         title,
      description:   description
    )
    Cases::RuleEngineService.new(ticket).evaluate!
    ticket
  end

  private

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
