# Plan-Catalogo-Cotizaciones V1 — la cotización que ve el cliente por su enlace
# (sin usuario): verla (se marca «Vista»), aceptarla con su nombre (y firma con el
# dedo en el celular) o rechazarla con un comentario. Mismo estilo que el portal.
class Public::QuotesController < PublicController
  layout 'public_document'

  before_action :set_quote
  around_action :use_account_locale

  def show
    @quote.update_column(:viewed_at, Time.current) if @quote.sent? && @quote.viewed_at.nil? # rubocop:disable Rails/SkipsModelValidations
  end

  def accept
    return redirect_to(public_quote_path(@quote.public_token)) unless @quote.open?

    name = params[:accepted_by_name].to_s.strip
    if name.blank?
      flash.now[:error] = I18n.t('public_quotes.name_required')
      return render :show, status: :unprocessable_entity
    end

    Quotes::StatusService.new(@quote).apply!('won', accepted_by_name: name, signature: signature_param,
                                                    note: I18n.t('public_quotes.accepted_note', name: name))
    redirect_to public_quote_path(@quote.public_token)
  end

  def reject
    return redirect_to(public_quote_path(@quote.public_token)) unless @quote.open?

    comment = params[:comment].to_s.strip.presence
    Quotes::StatusService.new(@quote).apply!('lost', note: [I18n.t('public_quotes.rejected_note'), comment].compact.join(': '))
    redirect_to public_quote_path(@quote.public_token)
  end

  private

  def set_quote
    @quote = Quote.includes(:account, :contact, :assignee, :items).find_by!(public_token: params[:token])
    @account = @quote.account
  end

  # En el idioma de la cuenta (como el portal del cliente).
  def use_account_locale(&)
    I18n.with_locale(@account.locale.presence || I18n.default_locale, &)
  end

  # Solo una imagen PNG en data-URL (la firma del lienzo), con un tope de tamaño.
  def signature_param
    data = params[:signature].to_s
    data if data.start_with?('data:image/png;base64,') && data.size < 400_000
  end
end
