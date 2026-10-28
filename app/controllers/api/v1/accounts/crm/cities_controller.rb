# CrmZeus O1 — ciudades: búsqueda para el selector (como el de CRMZeus, por las primeras
# letras) y alta al vuelo desde el formulario de la organización.
#
#   GET  /crm/cities   ?q= &state_id=
#   POST /crm/cities   { city: { name, state_id } }
class Api::V1::Accounts::Crm::CitiesController < Api::V1::Accounts::Crm::BaseController
  LIMIT = 30

  before_action :check_sales_write_access, only: %i[create]

  def index
    scope = cities.includes(state: :country).order(:name).limit(LIMIT)
    scope = scope.where(state_id: params[:state_id]) if params[:state_id].present?
    scope = scope.where('crm_cities.name ILIKE ?', "#{CrmCity.sanitize_sql_like(params[:q].to_s.strip)}%") if params[:q].present?
    render json: { cities: scope.map { |city| Crm::CatalogJson.city(city) } }
  end

  def create
    state = CrmState.where(account_id: Current.account.id).find(params.require(:city)[:state_id])
    city = state.cities.new(name: params[:city][:name])
    return render_errors(city) unless city.save

    render json: { city: Crm::CatalogJson.city(city) }, status: :created
  end

  private

  def cities
    CrmCity.where(account_id: Current.account.id)
  end
end
