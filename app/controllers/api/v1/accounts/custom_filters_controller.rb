class Api::V1::Accounts::CustomFiltersController < Api::V1::Accounts::BaseController
  # `check_authorization` autoriza la CLASE, asi que solo sirve de reja gruesa
  # para index/create. show/update/destroy se autorizan contra el registro
  # (@tickets_cases F2), porque el indice ya trae vistas de otros.
  before_action :check_authorization, only: [:index, :create]
  before_action :fetch_custom_filters, only: [:index]
  before_action :fetch_custom_filter, only: [:show, :update, :destroy]
  before_action :authorize_custom_filter, only: [:show, :update, :destroy]
  DEFAULT_FILTER_TYPE = 'conversation'.freeze

  def index; end

  def show; end

  def create
    @custom_filter = current_user.custom_filters.create!(
      permitted_payload.merge(account_id: Current.account.id)
    )
    render json: { error: @custom_filter.errors.messages }, status: :unprocessable_entity and return unless @custom_filter.valid?
  end

  def update
    @custom_filter.update!(permitted_payload)
  end

  def destroy
    @custom_filter.destroy!
    head :no_content
  end

  private

  # @tickets_cases F2 — las propias mas las compartidas por cualquiera de la
  # cuenta. Para los tres tipos previos el resultado es el mismo que antes:
  # ninguna de sus filas esta compartida.
  def fetch_custom_filters
    @custom_filters = CustomFilter.visible_for(
      current_user,
      account: Current.account,
      filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
    )
  end

  def authorize_custom_filter
    authorize(@custom_filter)
  end

  # Sin acotar por tipo: en show/update/destroy el `filter_type` viaja dentro del
  # cuerpo, no en la query string, asi que filtrar por el devolvia 404 sobre
  # vistas que el usuario si puede ver. El id ya identifica el registro; la
  # cuenta y la visibilidad son lo que hay que garantizar.
  def fetch_custom_filter
    @custom_filter = CustomFilter.visible_for(current_user, account: Current.account)
                                 .find(permitted_params[:id])
  end

  def permitted_payload
    params.require(:custom_filter).permit(
      :name,
      :filter_type,
      :shared, # @tickets_cases F2 — vista compartida con la cuenta
      query: {}
    )
  end

  def permitted_params
    params.permit(:id, :filter_type)
  end
end
