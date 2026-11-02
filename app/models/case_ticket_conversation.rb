# frozen_string_literal: true

# == Schema Information
#
# Table name: case_ticket_conversations
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  case_ticket_id  :bigint           not null
#  conversation_id :bigint           not null
#  linked_by_id    :bigint
#
# Indexes
#
#  idx_case_ticket_conversations_unique                (case_ticket_id,conversation_id) UNIQUE
#  index_case_ticket_conversations_on_account_id       (account_id)
#  index_case_ticket_conversations_on_case_ticket_id   (case_ticket_id)
#  index_case_ticket_conversations_on_conversation_id  (conversation_id)
#  index_case_ticket_conversations_on_linked_by_id     (linked_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (case_ticket_id => case_tickets.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (linked_by_id => users.id) ON DELETE => nullify
#
class CaseTicketConversation < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket
  belongs_to :conversation
  belongs_to :linked_by, class_name: 'User', optional: true

  validates :conversation_id, uniqueness: { scope: :case_ticket_id }
  validate :not_the_primary
  validate :same_contact

  private

  def not_the_primary
    errors.add(:conversation, 'ya es la conversación principal del caso') if conversation_id == case_ticket&.conversation_id
  end

  def same_contact
    return if conversation.nil? || case_ticket.nil?
    return if conversation.contact_id == case_ticket.contact_id && conversation.account_id == case_ticket.account_id

    errors.add(:conversation, 'no es del contacto del caso')
  end
end
