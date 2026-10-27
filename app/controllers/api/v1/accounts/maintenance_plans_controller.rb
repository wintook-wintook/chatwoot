# Plan-Trabajo-Campo R4 — mantenimientos recurrentes (contratos).
#
#   GET    /maintenance_plans?contact_id= &active=     (próximos primero)
#   POST   /maintenance_plans      PATCH /maintenance_plans/:id      DELETE /maintenance_plans/:id
#   POST   /maintenance_plans/:id/generate   genera ya la orden de la siguiente fecha
class Api::V1::Accounts::MaintenancePlansController < Api::V1::Accounts::BaseController
  FIELDS = %i[contact_id customer_asset_id case_type_id assignee_id title every unit next_due_on lead_days
              notify_customer active notes].freeze

  before_action :check_access
  before_action :check_writable, except: %i[index]
  before_action :set_plan, only: %i[update destroy generate]

  def index
    plans = Current.account.maintenance_plans.includes(:contact, :customer_asset, :case_type, :assignee).order(:next_due_on)
    plans = plans.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    plans = plans.active unless params[:active].to_s == 'all'
    render json: { maintenance_plans: plans.map { |plan| plan_json(plan) } }
  end

  def create
    plan = Current.account.maintenance_plans.new(plan_params)
    plan.save ? render(json: { maintenance_plan: plan_json(plan) }, status: :created) : render_errors(plan)
  end

  def update
    @plan.update(plan_params.except(:contact_id)) ? render(json: { maintenance_plan: plan_json(@plan) }) : render_errors(@plan)
  end

  def destroy
    @plan.destroy!
    head :no_content
  end

  def generate
    order = MaintenancePlans::Generator.new(@plan).call
    render json: { maintenance_plan: plan_json(@plan.reload), case_ticket: { id: order.id, folio: order.folio } }
  rescue ActiveRecord::RecordInvalid => e
    render_errors(e.record)
  end

  private

  def check_access
    render_access_denied unless access_grant.allowed?(:service) || access_grant.allowed?(:clients)
  end

  def check_writable
    render_access_denied unless access_grant.writable?(:service)
  end

  def set_plan
    @plan = Current.account.maintenance_plans.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('maintenance_plans.errors.not_found') }, status: :not_found
  end

  def plan_params
    params.require(:maintenance_plan).permit(*FIELDS)
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def plan_json(plan)
    { id: plan.id, title: plan.title, every: plan.every, unit: plan.unit, next_due_on: plan.next_due_on,
      lead_days: plan.lead_days, notify_customer: plan.notify_customer, active: plan.active, notes: plan.notes,
      last_generated_at: plan.last_generated_at,
      contact: ref(plan.contact), customer_asset: ref(plan.customer_asset), case_type: ref(plan.case_type),
      assignee: ref(plan.assignee), open_orders: plan.case_tickets.where.not(status: %w[closed cancelled]).count }
  end

  def ref(record)
    record && { id: record.id, name: record.name }
  end
end
