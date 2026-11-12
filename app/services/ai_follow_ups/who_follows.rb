# frozen_string_literal: true

# ¿Quién le está dando seguimiento? Para el botón «Delegar seguimiento»: si ya corre uno, se
# abre ese en vez de crear otro. Mira el Seguimiento IA y, SOLO LEYENDO, los seguimientos de
# los Agentes a medida (contact_trackings: otro motor, aquí no se cambia nada).
#
#   AiFollowUps::WhoFollows.new(account, conversations:, contact_ids:, case_ticket: nil).call
#   → { ai: AiFollowUp|nil, custom: ContactTracking|nil, custom_agents: true|false }
class AiFollowUps::WhoFollows
  LIVE_AI = %w[active paused].freeze

  def initialize(account, conversations:, contact_ids:, case_ticket: nil)
    @account = account
    @conversations = conversations
    @contact_ids = contact_ids
    @case_ticket = case_ticket
  end

  def call
    { ai: ai, custom: custom, custom_agents: @account.tracking_templates.exists?(archived_at: nil) }
  end

  private

  def ai
    scope = AiFollowUp.where(account_id: @account.id, status: LIVE_AI)
    scope = @case_ticket ? scope.where(case_ticket_id: @case_ticket.id) : scope.where(conversation_id: @conversations.select(:id))
    scope.order(created_at: :desc).first
  end

  def custom
    ContactTracking.active_or_scheduled.where(account_id: @account.id, contact_id: @contact_ids)
                   .includes(:tracking_template, :conversation).order(created_at: :desc).first
  end
end
