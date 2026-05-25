# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Controlador: TrackingTemplatesController
# Descripción: CRUD de plantillas de seguimiento (account-scoped)
# Acciones: index (filtros search/tag/inbox_id), show, create, update, destroy
# ================================================================================

class Api::V1::Accounts::TrackingTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_tracking_template, only: [:show, :update, :destroy]

  def index
    @tracking_templates = Current.account.tracking_templates.includes(:user, :inbox).ordered
    @tracking_templates = @tracking_templates.search_by_name(params[:search]) if params[:search].present?
    @tracking_templates = @tracking_templates.by_tag(params[:tag]) if params[:tag].present?
    @tracking_templates = @tracking_templates.by_inbox(params[:inbox_id]) if params[:inbox_id].present?
    render json: @tracking_templates.map { |t| template_json(t) }
  end

  def show
    render json: template_json(@tracking_template)
  end

  def create
    @tracking_template = Current.account.tracking_templates.new(tracking_template_params)
    @tracking_template.user = Current.user
    @tracking_template.save!
    render json: template_json(@tracking_template), status: :created
  end

  def update
    @tracking_template.update!(tracking_template_params)
    render json: template_json(@tracking_template)
  end

  def destroy
    @tracking_template.destroy!
    head :ok
  end

  def calendar_integrations
    integrations = UserCalendarIntegration.where(account: Current.account).includes(:user)
    render json: integrations.map { |i|
      { id: i.id, google_email: i.google_email, user_name: i.user.available_name || i.user.name }
    }
  end

  private

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:id])
  end

  def tracking_template_params
    params.require(:tracking_template).permit(
      :name, :objective, :ai_context, :complementary_prompt, :inbox_id,
      :retry_interval_value, :retry_interval_unit, # proyecto@automatizacion_tracking
      whatsapp_templates: [],
      tags: [],
      keyword_actions: [:keyword, :action, :direction], # proyecto@contact_tracking
      calendar_integration_ids: []
    )
  end

  def template_json(template)
    json = template.as_json(except: [:user_id])
    json['creator'] = if template.user
                        { id: template.user.id, name: template.user.available_name || template.user.name }
                      end
    json['inbox_name']      = template.inbox&.name
    json['keyword_actions'] = template.keyword_actions || [] # proyecto@contact_tracking
    json
  end
end
