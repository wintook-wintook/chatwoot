# Cotizaciones › Formatos — los formatos de la empresa y sus datos (encabezado).
#
#   GET    /quote_formats                     formatos, datos de la empresa, si hay PDF y si puede editar
#   POST   /quote_formats                     (quote_format: name, is_default, settings)
#   PATCH  /quote_formats/:id                 DELETE /quote_formats/:id (sus cotizaciones usan el de por omisión)
#   POST   /quote_formats/:id/duplicate       copia («… (copia)»)
#   POST   /quote_formats/:id/logo            (logo) · DELETE /quote_formats/:id/logo   el logo propio del formato
#   PATCH  /quote_formats/company             (company: legal_name, tax_id, address, phone, email, website)
#   POST   /quote_formats/company_logo        (logo) · DELETE /quote_formats/company_logo
#   POST   /quote_formats/preview             (settings, id?, quote_id?) → { html } con una cotización real o de ejemplo
#
# Los usa quien ve cotizaciones (para escoger el formato); los cambia quien edita el catálogo (Ventas en «Todo»).
class Api::V1::Accounts::QuoteFormatsController < Api::V1::Accounts::BaseController
  before_action :check_read_access
  before_action :check_write_access, except: %i[index preview]
  before_action :set_format, only: %i[update destroy duplicate logo remove_logo]

  def index
    QuoteFormat.ensure_for!(Current.account)
    render json: payload
  end

  def create
    format = Current.account.quote_formats.new(format_params)
    format.save ? render(json: payload, status: :created) : render_errors(format)
  end

  def update
    @format.update(format_params) ? render(json: payload) : render_errors(@format)
  end

  def destroy
    return render_error(I18n.t('quote_formats.errors.last')) if Current.account.quote_formats.count == 1

    was_default = @format.is_default?
    @format.destroy!
    Current.account.quote_formats.order(:id).first&.update!(is_default: true) if was_default
    render json: payload
  end

  def duplicate
    copy = Current.account.quote_formats.create!(name: "#{@format.name} (#{I18n.t('quote_formats.copy')})".first(80),
                                                 settings: @format.settings)
    copy.logo.attach(@format.logo.blob) if @format.logo.attached?
    render json: payload, status: :created
  end

  def logo
    return render_error(I18n.t('quote_formats.errors.logo')) unless image?(params[:logo])

    @format.logo.attach(params[:logo])
    render json: payload
  end

  def remove_logo
    @format.logo.purge if @format.logo.attached?
    render json: payload
  end

  def company
    setting = CaseSetting.for_account(Current.account)
    setting.update!(company_profile: Quotes::Company.clean(params.require(:company).permit(*QuoteFormat::COMPANY_FIELDS).to_h))
    render json: payload
  end

  def company_logo
    return render_error(I18n.t('quote_formats.errors.logo')) unless image?(params[:logo])

    CaseSetting.for_account(Current.account).company_logo.attach(params[:logo])
    render json: payload
  end

  def remove_company_logo
    setting = CaseSetting.for_account(Current.account)
    setting.company_logo.purge if setting.company_logo.attached?
    render json: payload
  end

  # La vista previa con lo que está en pantalla (sin guardar).
  def preview
    format = Current.account.quote_formats.find_by(id: params[:id]) || Current.account.quote_formats.new(name: 'preview')
    format.settings = Quotes::FormatSettings.clean(params.fetch(:settings, {}).to_unsafe_h) if params.key?(:settings)
    doc = Quotes::Document.new(Quotes::SampleQuote.for(Current.account, current_user, access_grant, params[:quote_id]), format: format)
    render json: { html: render_to_string(template: 'quotes/standalone', layout: false, locals: { doc: doc, pdf: false }, formats: [:html]) }
  end

  private

  def set_format
    @format = Current.account.quote_formats.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('quote_formats.errors.not_found') }, status: :not_found
  end

  def format_params
    permitted = params.require(:quote_format).permit(:name, :is_default)
    permitted[:settings] = params[:quote_format][:settings].to_unsafe_h if params[:quote_format][:settings].present?
    permitted
  end

  def payload
    setting = CaseSetting.for_account(Current.account)
    { formats: Current.account.quote_formats.ordered.map { |f| format_json(f) },
      company: Quotes::Company.clean(setting.company_profile.to_h).merge('logo_url' => logo_url(setting.company_logo)),
      account_name: Current.account.name, can_edit: writable?, pdf: Quotes::Pdf.available?,
      variables: Quotes::Document::VARIABLES, fonts: QuoteFormat::FONTS, blocks: QuoteFormat::BLOCKS,
      defaults: QuoteFormat::DEFAULTS }
  end

  def format_json(format)
    { id: format.id, name: format.name, is_default: format.is_default, settings: format.config,
      logo_url: logo_url(format.logo), quotes: format.quotes.count }
  end

  def logo_url(attachment)
    url_for(attachment) if attachment.attached?
  end

  def image?(file)
    file.respond_to?(:content_type) && CatalogItem::IMAGE_TYPES.include?(file.content_type.to_s) && file.size <= 2.megabytes
  end

  def writable? = access_grant.catalog_writable?

  def check_read_access
    render_access_denied unless access_grant.case_area_allowed?
  end

  def check_write_access
    render_access_denied unless writable?
  end

  def render_error(message)
    render json: { error: [message] }, status: :unprocessable_entity
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages }, status: :unprocessable_entity
  end
end
