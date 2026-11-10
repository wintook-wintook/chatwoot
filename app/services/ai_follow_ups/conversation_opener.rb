# frozen_string_literal: true

# Seguimiento IA desde la ficha de un contacto sin conversaciones: abre una conversación
# nueva en la bandeja que se elija para que el agente le escriba ahí.
#
#   AiFollowUps::ConversationOpener.inboxes_for(contact)            → [{ inbox:, source_id: }]
#   AiFollowUps::ConversationOpener.new(contact:, inbox:, user:).call → Conversation
#
# Solo bandejas por las que se le puede escribir primero: WhatsApp y SMS (con teléfono) y
# correo (con correo). WhatsApp va primero. La conversación queda asignada a quien delega.
class AiFollowUps::ConversationOpener
  CHANNELS = %w[Channel::Whatsapp Channel::Sms Channel::TwilioSms Channel::Email].freeze

  def self.inboxes_for(contact)
    Contacts::ContactableInboxesService.new(contact: contact).get
                                       .select { |entry| CHANNELS.include?(entry[:inbox].channel_type) }
                                       .sort_by { |entry| [CHANNELS.index(entry[:inbox].channel_type), entry[:inbox].name.to_s] }
  end

  def initialize(contact:, inbox:, user:)
    @contact = contact
    @inbox = inbox
    @user = user
  end

  def call
    entry = self.class.inboxes_for(@contact).find { |candidate| candidate[:inbox].id == @inbox.id }
    raise ArgumentError, 'No se le puede escribir a este contacto por esa bandeja. Revisa su teléfono o correo.' unless entry

    contact_inbox = ContactInboxBuilder.new(contact: @contact, inbox: @inbox, source_id: entry[:source_id]).perform
    Conversation.create!(account_id: @contact.account_id, inbox: @inbox, contact: @contact, contact_inbox: contact_inbox,
                         assignee: @user, status: :open)
  end
end
