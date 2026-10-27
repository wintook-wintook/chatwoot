# Plan-Contratos R1 — tipos de contrato de la empresa (Clientes › Tipos de contrato).
#
#   GET   /contract_types        ?active=true (para los formularios) o todos
#   POST  /contract_types        PATCH /contract_types/:id     (solo el Administrador)
#
# No se borran: se desactivan (los contratos que ya existen conservan su tipo).
class Api::V1::Accounts::ContractTypesController < Api::V1::Accounts::BaseController
  before_action :check_read_access, only: :index
  before_action :check_admin, except: :index
  before_action :set_type, only: :update

  def index
    types = Current.account.contract_types.ordered
    types = types.active if ActiveModel::Type::Boolean.new.cast(params[:active])
    counts = Current.account.contracts.where(contract_type_id: types.select(:id)).group(:contract_type_id).count
    render json: { contract_types: types.map { |type| type_json(type, counts[type.id].to_i) } }
  end

  def create
    type = Current.account.contract_types.new(type_params)
    type.save ? render(json: { contract_type: type_json(type, 0) }, status: :created) : render_errors(type)
  end

  def update
    @type.update(type_params) ? render(json: { contract_type: type_json(@type, @type.contracts.count) }) : render_errors(@type)
  end

  private

  def check_read_access
    render_access_denied unless access_grant.allowed?(:clients) || access_grant.allowed?(:sales)
  end

  def check_admin
    render_access_denied unless access_grant.admin?
  end

  def set_type
    @type = Current.account.contract_types.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('contracts.errors.type_not_found') }, status: :not_found
  end

  def type_params
    params.require(:contract_type).permit(:name, :color, :default_every, :default_unit, :default_term_months,
                                          :default_auto_renew, :active, :position, custom_fields: %i[key label type])
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def type_json(type, contracts_count)
    type.slice(:id, :name, :color, :default_every, :default_unit, :default_term_months, :default_auto_renew,
               :custom_fields, :active, :position).merge(contracts_count: contracts_count)
  end
end
