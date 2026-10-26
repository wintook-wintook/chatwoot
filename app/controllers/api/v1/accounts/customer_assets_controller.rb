# Plan-Trabajo-Campo R4 — equipos del cliente.
#
#   GET    /customer_assets?contact_id=   (los activos; &all=true también los dados de baja)
#   GET    /customer_assets/:id           con su historial de órdenes
#   POST   /customer_assets               PATCH /customer_assets/:id
class Api::V1::Accounts::CustomerAssetsController < Api::V1::Accounts::BaseController
  FIELDS = %i[contact_id name brand model serial location installed_on warranty_until notes active].freeze

  before_action :check_access
  before_action :set_asset, only: %i[show update]

  def index
    assets = Current.account.customer_assets.where(contact_id: params[:contact_id]).ordered
    assets = assets.active unless ActiveModel::Type::Boolean.new.cast(params[:all])
    counts = account_case_tickets.where(customer_asset_id: assets.select(:id)).group(:customer_asset_id).count
    render json: { customer_assets: assets.map { |asset| asset_json(asset, counts[asset.id].to_i) } }
  end

  def show
    orders = account_case_tickets.where(customer_asset_id: @asset.id).includes(:assignee, :case_type).order(created_at: :desc)
    render json: { customer_asset: asset_json(@asset, orders.size).merge(history: orders.map { |o| history_json(o) }) }
  end

  def create
    asset = Current.account.customer_assets.new(asset_params)
    asset.save ? render(json: { customer_asset: asset_json(asset, 0) }, status: :created) : render_errors(asset)
  end

  def update
    @asset.update(asset_params.except(:contact_id)) ? render(json: { customer_asset: asset_json(@asset, 0) }) : render_errors(@asset)
  end

  private

  def check_access
    render_access_denied unless access_grant.allowed?(:clients) || access_grant.case_area_allowed?
  end

  def set_asset
    @asset = Current.account.customer_assets.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('maintenance_plans.errors.asset_not_found') }, status: :not_found
  end

  def asset_params
    params.require(:customer_asset).permit(*FIELDS)
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def asset_json(asset, orders_count)
    { id: asset.id, contact_id: asset.contact_id, name: asset.name, brand: asset.brand, model: asset.model,
      serial: asset.serial, location: asset.location, installed_on: asset.installed_on,
      warranty_until: asset.warranty_until, under_warranty: asset.under_warranty?, notes: asset.notes,
      active: asset.active, orders_count: orders_count }
  end

  def history_json(order)
    { id: order.id, folio: order.folio, title: order.title, status: order.status, created_at: order.created_at,
      resolved_at: order.resolved_at, assignee: order.assignee&.name, report_sent_at: order.report_sent_at }
  end
end
