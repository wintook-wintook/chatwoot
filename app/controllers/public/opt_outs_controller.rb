# prospeccion V4 — la baja que pide el contacto desde el enlace de un correo (sin usuario).
#   GET  /baja/:token → página «¿Confirmas?» (los antivirus abren los enlaces solos: abrir no da de baja)
#   POST /baja/:token → da de baja. Es también la «baja con un clic» de Gmail y Yahoo
#                       (List-Unsubscribe-Post: List-Unsubscribe=One-Click), que no ve la página.
class Public::OptOutsController < PublicController
  layout 'public_document'

  before_action :set_contact
  around_action :use_account_locale

  def show; end

  def create
    ContactTrackings::OptOut.call(@contact, source: 'link')
    return head(:ok) if params['List-Unsubscribe'] == 'One-Click'

    render :show
  end

  private

  def set_contact
    @contact = ContactTrackings::OptOut.contact_for(params[:token])
    return render(plain: 'Not found', status: :not_found) unless @contact

    @account = @contact.account
  end

  def use_account_locale(&)
    I18n.with_locale(@account&.locale.presence || I18n.default_locale, &)
  end
end
