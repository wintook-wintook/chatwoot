# frozen_string_literal: true

# feat/apariencia B1 — LA MARCA DE LA EMPRESA
# PATCH  /api/v1/accounts/:account_id/brand   { tint } y/o { logo } (archivo)
# DELETE /api/v1/accounts/:account_id/brand   quita el logo
# El color es uno de los temas del tablero (la misma rampa en claro y oscuro); es el de
# todos los agentes salvo quien elija otro en su Apariencia. Solo administradores.
class Api::V1::Accounts::BrandsController < Api::V1::Accounts::BaseController
  TINTS = %w[default calido bosque indigo sepia contraste violeta turquesa rosa grafito].freeze
  LOGO_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_SIZE = 2.megabytes

  before_action :check_admin_authorization?

  def update
    error = invalid_params
    return render_error(error) if error

    account = Current.account
    account.custom_attributes['brand_tint'] = params[:tint] if params.key?(:tint)
    account.brand_logo.attach(params[:logo]) if params[:logo].present?
    account.save!
    render json: brand_json
  end

  def destroy
    Current.account.brand_logo.purge if Current.account.brand_logo.attached?
    render json: brand_json
  end

  private

  def invalid_params
    return I18n.t('brand.errors.tint') if params.key?(:tint) && TINTS.exclude?(params[:tint])

    I18n.t('brand.errors.logo') if params[:logo].present? && !valid_logo?(params[:logo])
  end

  def valid_logo?(file)
    file.respond_to?(:content_type) && LOGO_TYPES.include?(file.content_type) && file.size <= LOGO_MAX_SIZE
  end

  def brand_json
    { tint: Current.account.brand_tint, logo_url: Current.account.brand_logo_url }
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
