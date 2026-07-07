# frozen_string_literal: true

# @waba_templates — CRUD de plantillas de WhatsApp (crear/submit/editar/borrar contra Meta).
# Solo administradores. Alcance por cuenta + canal (inbox de WhatsApp).
class Api::V1::Accounts::Whatsapp::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_channel, only: [:index, :create]
  before_action :fetch_template, only: [:show, :update, :destroy]

  def index
    templates = Current.account.whatsapp_templates.for_channel(@channel.id).order(:name)
    render json: templates.map { |t| template_json(t) }
  end

  def show
    render json: template_json(@template)
  end

  def create
    result = Whatsapp::SubmitTemplateService.new(channel: @channel, params: template_params).create
    render_result(result, ok_status: :created)
  end

  def update
    result = Whatsapp::SubmitTemplateService.new(template: @template, params: template_params).update
    render_result(result)
  end

  def destroy
    result = Whatsapp::SubmitTemplateService.new(template: @template).destroy
    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    head :ok
  end

  private

  def fetch_channel
    inbox = Current.account.inboxes.find(params[:inbox_id])
    @channel = inbox.channel
    return if @channel.is_a?(Channel::Whatsapp)

    render json: { error: 'El inbox no es un canal de WhatsApp' }, status: :unprocessable_entity
  end

  def fetch_template
    @template = Current.account.whatsapp_templates.find(params[:id])
  end

  def template_params
    params.require(:whatsapp_template).permit(
      :name, :category, :language, :header_type, :header_content, :header_media_url,
      :body_text, :footer_text,
      buttons: [:type, :text, :url, :phone_number, { example: [] }],
      sample_values: { body: [], header: [] }
    )
  end

  def render_result(result, ok_status: :ok)
    if result.success?
      render json: template_json(result.template), status: ok_status
    else
      body = { error: result.error, drift: result.drift }.compact
      body[:template] = template_json(result.template) if result.template&.persisted?
      render json: body, status: :unprocessable_entity
    end
  end

  def template_json(template)
    {
      id: template.id,
      name: template.name,
      category: template.category,
      language: template.language,
      status: template.status,
      quality_score: template.quality_score,
      rejection_reason: template.rejection_reason,
      header_type: template.header_type,
      header_content: template.header_content,
      header_media_url: template.header_media_url,
      body_text: template.body_text,
      footer_text: template.footer_text,
      buttons: template.buttons,
      sample_values: template.sample_values,
      meta_template_id: template.meta_template_id,
      submission_error: template.submission_error,
      last_submitted_at: template.last_submitted_at,
      editable: template.editable?,
      local_only: template.local_only?
    }
  end
end
