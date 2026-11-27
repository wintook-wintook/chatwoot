# CrmZeus Q4.1 — la cotización de CrmZeus que ve el cliente por su enlace (`/cotizacion-crm/:token`),
# sin usuario. Solo se ve e imprime (decisión del usuario: sin aceptar ni rechazar, como CRMZeus);
# una cotización no Pendiente enseña su estatus. Mismo layout que la de `quotes` de develop.
class Public::CrmQuotesController < PublicController
  layout 'public_document'

  before_action :set_quote
  around_action :use_account_locale

  def show
    @show_components = CrmSetting.for_account(@account).show_kit_components
  end

  private

  def set_quote
    address = { city: { state: :country } }
    @quote = CrmQuote.includes(:account, :contact, :seller, :payment_term, :currency, :taxes, :items,
                               shipping_address: address, organization: { home_address: address })
                     .find_by!(public_token: params[:token])
    @account = @quote.account
  end

  # En el idioma de la cuenta (como la cotización de develop).
  def use_account_locale(&)
    I18n.with_locale(@account.locale.presence || I18n.default_locale, &)
  end
end
