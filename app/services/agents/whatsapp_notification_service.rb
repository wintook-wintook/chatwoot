# ================================================================================
# proyecto@user_contact
# ================================================================================
module Agents
  class WhatsappNotificationService
    def initialize(account:, user:, message:, inbox: nil)
      @account = account
      @user = user
      @message = message
      @inbox = inbox
    end

    def perform
      unless agent_contact.present?
        Rails.logger.warn "[AgentWhatsapp] User #{@user.id} has no agent_contact assigned in account #{@account.id}"
        return false
      end

      unless whatsapp_inbox.present?
        Rails.logger.warn "[AgentWhatsapp] No WhatsApp inbox available in account #{@account.id}"
        return false
      end

      conversation = find_or_create_conversation
      send_message(conversation)
      true
    end

    private

    def agent_contact
      @agent_contact ||= AccountUser
        .find_by(account: @account, user: @user)
        &.agent_contact
    end

    def whatsapp_inbox
      @whatsapp_inbox ||= @inbox ||
        @account.inboxes.where(channel_type: 'Channel::Whatsapp').first
    end

    def find_or_create_conversation
      conversation = Conversation.where(
        account_id: @account.id,
        inbox_id: whatsapp_inbox.id,
        contact_id: agent_contact.id,
        status: %w[open pending]
      ).last

      return conversation if conversation

      contact_inbox = ContactInbox.find_or_create_by!(
        contact_id: agent_contact.id,
        inbox_id: whatsapp_inbox.id
      ) do |ci|
        ci.source_id = agent_contact.phone_number ||
                       agent_contact.identifier ||
                       agent_contact.email
      end

      Conversation.create!(
        account_id: @account.id,
        inbox_id: whatsapp_inbox.id,
        contact_id: agent_contact.id,
        contact_inbox_id: contact_inbox.id,
        status: :open
      )
    end

    def send_message(conversation)
      Messages::MessageBuilder.new(
        @user,
        conversation,
        {
          content: @message,
          message_type: 'outgoing',
          private: false
        }
      ).perform
    end
  end
end
