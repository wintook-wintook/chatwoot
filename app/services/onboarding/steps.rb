# frozen_string_literal: true

# «Primeros pasos» (Inicio) — qué ya hizo este usuario, revisado en vivo con lo que hay en la
# cuenta: no guarda nada ni se palomea a mano. Los pasos de administrador (WhatsApp y equipo)
# solo los ve un administrador. Lo demás va con los permisos de quien pregunta (Access::Grant).
#   Onboarding::Steps.new(account:, user:, grant:).call → [{ key:, done: }, …] en orden
class Onboarding::Steps
  ADMIN_STEPS = %w[whatsapp team].freeze
  STEPS = %w[whatsapp team organization contact case meeting follow_up dali].freeze

  def initialize(account:, user:, grant:)
    @account = account
    @user = user
    @grant = grant
  end

  def call
    STEPS.reject { |key| ADMIN_STEPS.include?(key) && !@grant.admin? }
         .map { |key| { key: key, done: public_send("#{key}?") } }
  end

  def whatsapp?
    @account.inboxes.exists?(channel_type: 'Channel::Whatsapp')
  end

  def team?
    @account.account_users.count > 1
  end

  def organization?
    @account.organizations.exists?
  end

  # Un contacto que ve, ligado a su organización.
  def contact?
    @grant.contacts(@account.contacts).where.not(organization_id: nil).exists?
  end

  def case?
    @grant.case_tickets(@account.case_tickets).exists?
  end

  def meeting?
    @account.case_meetings.exists?(organizer_id: @user.id)
  end

  def follow_up?
    AiFollowUp.exists?(account_id: @account.id, created_by_id: @user.id)
  end

  def dali?
    AssistantThread.where(account_id: @account.id, user_id: @user.id).where('jsonb_array_length(messages) > 0').exists?
  end
end
