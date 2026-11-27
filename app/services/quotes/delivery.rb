# Plan-Catalogo-Cotizaciones V1 — manda al cliente el enlace de su cotización por
# su conversación más reciente (WhatsApp, correo, web…) y la marca enviada.
# Cotizaciones › Formatos: con el PDF de su formato adjunto (si el servidor puede generarlo; si no, solo la liga).
class Quotes::Delivery
  Error = Class.new(StandardError)

  def initialize(quote, user)
    @quote = quote
    @user = user
  end

  def deliver!
    conversation = latest_conversation
    raise Error, I18n.t('quotes.errors.no_conversation') unless conversation

    params = { content: content, message_type: 'outgoing' }
    pdf = pdf_blob
    params[:attachments] = [pdf.signed_id] if pdf
    message = Messages::MessageBuilder.new(@user, conversation, params).perform
    Quotes::StatusService.new(@quote, actor: @user).apply!('sent') if @quote.draft?
    message
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.join(', ')
  end

  private

  def pdf_blob
    return unless Quotes::Pdf.available?

    Quotes::Pdf.new(@quote).blob
  rescue Quotes::Pdf::Error, ActiveStorage::Error => e
    Rails.logger.warn("[Quotes::Delivery] PDF de #{@quote.id}: #{e.message}")
    nil
  end

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
