# Evento de prueba del panel de Meta.
#
# Cuando pulsas "Test" en la configuración del webhook —y cuando el revisor valida la
# integración durante App Review— Meta manda un payload de mentira: ids fijos (12334 /
# 23245) y, en el canal nativo, envuelto en `changes` en lugar de `messaging`. Nada de eso
# se corresponde con una cuenta real, así que no se puede resolver el inbox por el IGSID
# como en el flujo normal.
#
# Sirve para que la prueba de Meta vea un mensaje entrar: sin eso la revisión concluye que
# la integración no funciona.
# @see https://developers.facebook.com/docs/instagram-platform/webhooks#event-notifications
class Instagram::TestEventService
  TEST_SENDER = '12334'.freeze
  TEST_RECIPIENT = '23245'.freeze

  def initialize(messaging)
    @messaging = messaging.with_indifferent_access
  end

  def perform
    return false unless test_event?

    inbox = target_inbox
    return false if inbox.blank?

    Rails.logger.info("[Instagram] evento de prueba de Meta, se materializa en el inbox #{inbox.id}")
    create_message(inbox)
    true
  end

  private

  def test_event?
    @messaging.dig(:sender, :id) == TEST_SENDER && @messaging.dig(:recipient, :id) == TEST_RECIPIENT
  end

  # El payload de prueba no identifica ninguna cuenta, así que no hay forma de acertar el
  # inbox: se usa el canal de Instagram conectado más recientemente, que durante una
  # revisión o una prueba manual es justo el que se acaba de dar de alta. Antes se cogía
  # la última Channel::FacebookPage de toda la instalación, que podía ser de otra cuenta
  # y ni siquiera tener Instagram.
  def target_inbox
    channel = Channel::Instagram.last || Channel::FacebookPage.where.not(instagram_id: nil).last
    return if channel.blank?

    ::Inbox.find_by(channel: channel)
  end

  def create_message(inbox)
    contact_inbox = find_or_create_contact_inbox(inbox)
    conversation = find_or_create_conversation(inbox, contact_inbox)

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: 'incoming',
      source_id: @messaging.dig(:message, :mid),
      content: @messaging.dig(:message, :text),
      sender: contact_inbox.contact
    )
  end

  def find_or_create_contact_inbox(inbox)
    inbox.contact_inboxes.find_by(source_id: TEST_SENDER) ||
      inbox.channel.create_contact_inbox(TEST_SENDER, 'sender_username')
  end

  def find_or_create_conversation(inbox, contact_inbox)
    params = {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      additional_attributes: { type: 'instagram_direct_message' }
    }

    Conversation.find_by(params) || Conversation.create!(params.merge(contact_inbox_id: contact_inbox.id))
  end
end
