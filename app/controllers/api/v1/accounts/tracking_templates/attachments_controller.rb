# ================================================================================
# proyecto@ai_agent_attachments
# ================================================================================
# Controlador: TrackingTemplates::AttachmentsController
# Descripción: CRUD de adjuntos de un Agente IA (anidado bajo tracking_templates,
#   account-scoped). Cada adjunto tiene un `name` (slug) que la directiva
#   {{name}} usa en el prompt complementario.
# Acciones: index, create (multipart: file + name), update (renombrar), destroy
# ================================================================================

class Api::V1::Accounts::TrackingTemplates::AttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_tracking_template
  before_action :fetch_attachment, only: [:update, :destroy]

  def index
    render json: @tracking_template.ai_agent_attachments.order(:name).map { |a| attachment_json(a) }
  end

  def create
    attachment = @tracking_template.ai_agent_attachments.new(name: params[:name], account: Current.account)
    attachment.file.attach(params[:file]) if params[:file].present?
    attachment.save!
    render json: attachment_json(attachment), status: :created
  end

  def update
    old_name = @attachment.name
    @attachment.update!(name: params[:name])
    # Mantiene vivas las referencias {{viejo}} → {{nuevo}} en el agente y sus seguimientos
    if old_name != @attachment.name
      AiAgentAttachments::DirectiveReferenceService.rename(@tracking_template, old_name, @attachment.name)
    end
    render json: attachment_json(@attachment)
  end

  def destroy
    name = @attachment.name
    @attachment.destroy!
    # Limpia las referencias {{name}} colgantes en el agente y sus seguimientos vivos
    AiAgentAttachments::DirectiveReferenceService.remove(@tracking_template, name)
    head :ok
  end

  private

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:tracking_template_id])
  end

  def fetch_attachment
    @attachment = @tracking_template.ai_agent_attachments.find(params[:id])
  end

  def attachment_json(attachment)
    file = attachment.file
    {
      id: attachment.id,
      name: attachment.name,
      filename: file.attached? ? file.filename.to_s : nil,
      byte_size: file.attached? ? file.byte_size : nil,
      content_type: file.attached? ? file.content_type : nil,
      url: file.attached? ? url_for(file) : nil,
      created_at: attachment.created_at
    }
  end
end
