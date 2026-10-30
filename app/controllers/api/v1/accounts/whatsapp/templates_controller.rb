# frozen_string_literal: true

# @waba_templates — CRUD de plantillas de WhatsApp (crear/submit/editar/borrar contra Meta).
# Solo administradores. Alcance por cuenta + canal (inbox de WhatsApp).
class Api::V1::Accounts::Whatsapp::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :check_feature_enabled
  before_action :fetch_channel, only: [:create, :sync]
  before_action :fetch_template, only: [:show, :update, :destroy, :usage]

  # Nivel cuenta: todas las plantillas de todos los canales de WhatsApp.
  # Filtro opcional por canal vía inbox_id (para la tabla del dashboard).
  def index
    templates = Current.account.whatsapp_templates.includes(:created_by).order(updated_at: :desc)
    templates = templates.for_channel(inbox_channel_id) if params[:inbox_id].present?
    render json: templates.map { |t| template_json(t) }
  end

  def show
    render json: template_json(@template)
  end

  # F10: con `draft: true` se guarda como borrador, sin llamar a Meta.
  def create
    servicio = Whatsapp::SubmitTemplateService.new(channel: @channel, params: template_params, user: Current.user)
    render_result(draft? ? servicio.save_draft : servicio.create, ok_status: :created)
  end

  def update
    servicio = Whatsapp::SubmitTemplateService.new(template: @template, params: template_params)
    render_result(draft? ? servicio.save_draft : servicio.update)
  end

  def destroy
    result = Whatsapp::SubmitTemplateService.new(template: @template).destroy
    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    head :ok
  end

  # Dónde se usa: el modal de borrar avisa qué envíos van a fallar.
  def usage
    render json: Whatsapp::TemplateUsage.call(@template)
  end

  # feat/plantillas_whatsapp_mejoras F6: sube el archivo de muestra del encabezado ANTES de
  # crear la plantilla (Meta lo pide al crearla). Se revisa con los límites de Meta del tipo
  # (los de ResumableUploadService) y se devuelve su signed_id: al crear o editar va como
  # `header_sample` y ActiveStorage lo pega a la plantilla.
  def header_samples
    archivo = params[:file]
    error = Whatsapp::ResumableUploadService.file_error(archivo, params[:header_type])
    return render json: { error: error }, status: :unprocessable_entity if error

    blob = ActiveStorage::Blob.create_and_upload!(io: archivo, filename: archivo.original_filename,
                                                  content_type: archivo.content_type)
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s, byte_size: blob.byte_size,
                   content_type: blob.content_type, url: blob_link(blob) }, status: :created
  end

  # Reconcilia desde Meta (upsert por fila) — fallback si el webhook no está suscrito.
  def sync
    result = Whatsapp::TemplateSyncService.new(@channel).perform
    render json: { synced: result.synced, created: result.created, updated: result.updated }
  rescue StandardError => e
    Rails.logger.error "[waba_templates] sync falló para canal ##{@channel&.id}: #{e.message}"
    render json: { error: "No se pudo sincronizar con Meta: #{e.message}" }, status: :unprocessable_entity
  end

  # Importa AL INSTANTE lo que cada canal ya tiene en cache (message_templates), sin llamar a
  # Meta. Se dispara al abrir el dashboard para que veas las aprobadas/en revisión de una vez.
  def import
    totals = { synced: 0, created: 0, updated: 0 }
    whatsapp_channels.each do |channel|
      result = Whatsapp::TemplateSyncService.new(channel).perform(source: :cache)
      totals[:synced] += result.synced
      totals[:created] += result.created
      totals[:updated] += result.updated
    end
    render json: totals
  end

  private

  def blob_link(blob)
    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    blob.url(expires_in: 1.hour)
  end

  def whatsapp_channels
    Current.account.inboxes.map(&:channel).grep(Channel::Whatsapp)
  end

  # @waba_templates — flag por cuenta, toggleable desde el super admin.
  def check_feature_enabled
    return if Current.account.feature_enabled?('whatsapp_templates')

    render json: { error: 'La gestión de plantillas de WhatsApp no está habilitada en esta cuenta.' }, status: :forbidden
  end

  def fetch_channel
    inbox = Current.account.inboxes.find(params[:inbox_id])
    @channel = inbox.channel
    return if @channel.is_a?(Channel::Whatsapp)

    render json: { error: 'El inbox no es un canal de WhatsApp' }, status: :unprocessable_entity
  end

  def inbox_channel_id
    Current.account.inboxes.find(params[:inbox_id]).channel_id
  end

  def draft?
    ActiveModel::Type::Boolean.new.cast(params[:draft])
  end

  def fetch_template
    @template = Current.account.whatsapp_templates.find(params[:id])
  end

  def template_params
    params.require(:whatsapp_template).permit(
      :name, :category, :language, :header_type, :header_content, :header_media_url, :header_sample,
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
      channel_whatsapp_id: template.channel_whatsapp_id,
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
    }.merge(sample_json(template), audit_json(template))
  end

  # La lista muestra cuándo se creó, la última actualización y quién la creó (F10).
  def audit_json(template)
    autor = template.created_by
    { created_at: template.created_at, updated_at: template.updated_at,
      created_by: autor ? { id: autor.id, name: autor.name } : nil }
  end

  # F6: el archivo subido (si lo hay) y una liga fresca para la vista previa.
  def sample_json(template)
    archivo = template.header_sample
    # signed_id: para «Duplicar» (F10.4), la copia pega el mismo archivo.
    { header_sample: archivo.attached? ? { filename: archivo.filename.to_s, signed_id: archivo.blob.signed_id } : nil,
      header_media_link: template.header_media_link }
  end
end
