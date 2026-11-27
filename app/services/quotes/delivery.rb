# Plan-Catalogo-Cotizaciones V1 — manda al cliente el enlace de su cotización por
# su conversación más reciente (WhatsApp, correo, web…) y la marca enviada.
# Cotizaciones › Formatos: con el PDF de su formato adjunto (si el servidor puede generarlo; si no, solo la liga).
class Quotes::Delivery
  Error = Class.new(StandardError)

  # ai_agent: { name: } cuando la manda un agente de IA (Motor2::Skills::Quote): el mensaje sale como suyo y no
  # cuenta como que una persona entró a la plática (si no, el agente se pausaba: Motor2::Reply#human_stepped_in?).
  def initialize(quote, user, ai_agent: nil)
    @quote = quote
    @user = user
    @ai_agent = ai_agent
  end

  def deliver!
    conversation = latest_conversation
    raise Error, I18n.t('quotes.errors.no_conversation') unless conversation

    params = { content: content, message_type: 'outgoing' }
    params[:ai_agent] = @ai_agent if @ai_agent.is_a?(Hash)
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

  # En el idioma de la cuenta: desde un agente (Sidekiq) no hay idioma de la pantalla y salía en inglés.
  def content
    I18n.with_locale(@quote.account.locale.presence || I18n.locale) do
      I18n.t('quotes.delivery_message', name: @quote.contact.name.to_s.split.first || '', folio: @quote.folio,
                                        url: Quotes::Serializer.public_url(@quote))
    end
  end
end
