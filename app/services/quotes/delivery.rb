# Plan-Catalogo-Cotizaciones V1 — manda al cliente el enlace de su cotización por
# su conversación más reciente (WhatsApp, correo, web…) y la marca enviada.
class Quotes::Delivery
  Error = Class.new(StandardError)

  def initialize(quote, user)
    @quote = quote
    @user = user
  end

  def deliver!
    conversation = latest_conversation
    raise Error, I18n.t('quotes.errors.no_conversation') unless conversation

    message = Messages::MessageBuilder.new(@user, conversation, { content: content, message_type: 'outgoing' }).perform
    Quotes::StatusService.new(@quote, actor: @user).apply!('sent') if @quote.draft?
    message
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.join(', ')
  end

  private

  def latest_conversation
    conversations = @quote.account.conversations.where(contact_id: @quote.contact_id)
    conversations.where(status: %i[open pending]).order(last_activity_at: :desc).first ||
      conversations.order(last_activity_at: :desc).first
  end

  def content
    I18n.t('quotes.delivery_message', name: @quote.contact.name.to_s.split.first || '', folio: @quote.folio,
                                      url: Quotes::Serializer.public_url(@quote))
  end
end
