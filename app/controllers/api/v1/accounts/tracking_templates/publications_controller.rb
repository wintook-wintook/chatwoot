# ================================================================================
# proyecto@publicar_prompts
# ================================================================================
# Controlador: TrackingTemplates::PublicationsController
# Descripción: la publicación del prompt de un Agente IA (anidado bajo tracking_templates,
#   account-scoped). Solo el usuario que el super admin marcó con "Puede publicar
#   prompts" llega aquí; los demás reciben 403 aunque llamen a mano.
# Acciones: show (estado + qué tendría que configurar quien lo baje),
#   create (publicar o sacar versión nueva), destroy (despublicar)
# Plan: docs/publicar_prompts_plan.md (F2)
# ================================================================================

class Api::V1::Accounts::TrackingTemplates::PublicationsController < Api::V1::Accounts::BaseController
  before_action :ensure_can_publish
  before_action :fetch_tracking_template

  def show
    render json: publication_json
  end

  def create
    publisher.publish!(**publication_params.to_h.symbolize_keys)
    render json: publication_json, status: :created
  end

  def destroy
    publisher.unpublish!
    render json: publication_json
  end

  private

  def ensure_can_publish
    return if Current.user&.can_publish_prompts?

    render json: { error: 'No tienes permiso para publicar prompts' }, status: :forbidden
  end

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:tracking_template_id])
  end

  def publisher
    @publisher ||= PublishedPrompts::Publisher.new(@tracking_template, Current.user)
  end

  def publication_params
    params.fetch(:publication, {}).permit(:title, :description, :category, attachment_ids: [])
  end

  PUBLICATION_FIELDS = %i[id title description category version status downloads_count published_at requirements].freeze

  # `publication` es null mientras el agente no se haya publicado nunca. `preview` es lo
  # que se publicaría HOY (requisitos detectados en el prompt actual), para el modal.
  # `attachments`: los archivos del agente, para elegir cuáles viajan (F6).
  def publication_json
    pub = publisher.publication
    {
      publication: (pub.as_json(only: PUBLICATION_FIELDS).merge('files' => pub.files.map(&:summary)) if pub.persisted?),
      preview: { requirements: PublishedPrompts::Snapshot.new(@tracking_template).attributes[:requirements] },
      attachments: attachments_json(pub),
      categories: PublishedPrompt::CATEGORIES
    }
  end

  # `referenced`: el prompt lo usa con {{nombre}}; `included`: va en la versión publicada.
  def attachments_json(pub)
    usados = PublishedPrompts::Requirements.attachments(@tracking_template.complementary_prompt.to_s).pluck('name').map(&:downcase)
    publicados = pub.persisted? ? pub.files.map { |f| f.name.downcase } : []
    agent_attachments.map do |adjunto|
      nombre = adjunto.name.downcase
      { id: adjunto.id, name: adjunto.name, filename: adjunto.file.filename.to_s, byte_size: adjunto.file.byte_size,
        referenced: usados.include?(nombre), included: publicados.include?(nombre) }
    end
  end

  def agent_attachments
    @tracking_template.ai_agent_attachments.includes(file_attachment: :blob).order(:name).select { |a| a.file.attached? }
  end
end
