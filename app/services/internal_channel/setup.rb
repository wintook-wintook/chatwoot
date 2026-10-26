# frozen_string_literal: true

# feat/chat_interno (plan v2, R1) — DEJAR LISTA LA BANDEJA «INTERNO» DE UNA CUENTA
# ============================================================================
# Idempotente: se puede correr cuantas veces sea (al entrar al dashboard, al cambiar
# equipos o agentes). Con el chat apagado en la cuenta no crea nada.
#   · la bandeja (sin asignación automática) y todos los agentes como miembros
#   · un contacto oculto «Chat interno» (Chatwoot exige contacto en cada conversación)
#   · la conversación # general (participan todos) y una por equipo (sus miembros)
# Cada conversación interna lleva additional_attributes['internal'] = { kind, team_id, key }.
# ============================================================================
class InternalChannel::Setup
  CONTACT_IDENTIFIER = 'internal-chat'
  CONTACT_NAME = 'Chat interno'

  def initialize(account)
    @account = account
  end

  def call
    return nil unless @account.internal_chat_enabled?

    ActiveRecord::Base.transaction do
      channel = Channel::Internal.find_or_create_by!(account_id: @account.id)
      @inbox = channel.inbox || @account.inboxes.create!(channel: channel, name: 'Interno', enable_auto_assignment: false)
      sync_members
      sync_general
      @account.teams.find_each { |team| sync_team(team) }
    end
    @inbox
  end

  def inbox
    @inbox ||= Channel::Internal.find_by(account_id: @account.id)&.inbox
  end

  def contact_inbox
    @contact_inbox ||= begin
      contact = @account.contacts.find_or_create_by!(identifier: CONTACT_IDENTIFIER) { |c| c.name = CONTACT_NAME }
      ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) { |ci| ci.source_id = CONTACT_IDENTIFIER }
    end
  end

  # La conversación interna de un tipo y llave (o se crea), con sus participantes al día.
  def conversation_for(kind:, key:, user_ids:, team_id: nil)
    conversation = inbox.conversations.where("additional_attributes -> 'internal' ->> 'key' = ?", key).first ||
                   create_conversation(kind: kind, key: key, team_id: team_id)
    sync_participants(conversation, user_ids)
    conversation
  end

  def sync_team(team)
    return unless inbox

    conversation_for(kind: 'team', key: "team:#{team.id}", team_id: team.id, user_ids: team.members.pluck(:id))
  end

  private

  def sync_members
    @account.users.pluck(:id).each { |user_id| InboxMember.find_or_create_by!(inbox: inbox, user_id: user_id) }
  end

  def sync_general
    conversation_for(kind: 'general', key: 'general', user_ids: @account.users.pluck(:id))
  end

  def create_conversation(kind:, key:, team_id:)
    @account.conversations.create!(
      inbox: inbox, contact: contact_inbox.contact, contact_inbox: contact_inbox, status: :open,
      additional_attributes: { 'internal' => { 'kind' => kind, 'key' => key, 'team_id' => team_id }.compact }
    )
  end

  # Los participantes son quienes ven la conversación (privacidad, plan v2 A2).
  def sync_participants(conversation, user_ids)
    current = conversation.conversation_participants.pluck(:user_id)
    (user_ids - current).each do |user_id|
      conversation.conversation_participants.create!(user_id: user_id, last_read_at: Time.current)
    end
    conversation.conversation_participants.where(user_id: current - user_ids).delete_all
  end
end
