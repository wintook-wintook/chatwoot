# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL ENCARGO (.md) DE UN AGENTE IA
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/briefs
#   (multipart: file, session_id opcional) Guarda el encargo. 201 si es nuevo; 200 si
#   ya estaba en esa conversación. `reused: 'reading'` = otro encargo de la cuenta con
#   el mismo archivo ya se había leído y la lectura se copió. Ver BriefIntake.
#
#   Un encargo nuevo se manda a leer solo (AgentBriefDigestJob); `turn_id` opcional para
#   seguir el avance en …/assistant/progress/:turn_id.
#
# POST …/assistant/briefs/:id/digest  (turn_id opcional)
#   Volver a leerlo, por ejemplo después de una falla. Lo ya leído no se vuelve a pagar.
#   202 si se encoló; 200 si ya estaba leído.
#
# POST …/assistant/briefs/from_instructions  (content, filename, session_id, turn_id)
#   Lo mismo que subir un archivo, con las instrucciones que se llenaron conversando
#   (DraftingChat) en vez de un .md. Mismas respuestas que POST …/briefs.
#
# GET …/assistant/briefs/:id
#   Datos del encargo, sin el texto. Con la ficha y lo que falta cuando ya se leyó.
#
# POST …/assistant/briefs/:id/compose  (answers: lo que la persona contestó)
#   El encargo ya resuelto, como mensaje para la redacción de una sola vez del Asistente
#   (…/assistant/interview con one_shot), y el objetivo y contexto para la Definición.
#   Guarda las respuestas en el encargo: regenerar no las vuelve a preguntar. Ver
#   BriefComposer.
#
# POST …/assistant/briefs/:id/cover  (draft: lo que escribió el Asistente)
#   El mismo Entrenamiento con lo que la redacción dejó afuera del encargo agregado en su
#   sección, sin IA. `added`: qué se agregó. Ver BriefCoverage.
#
# GET …/assistant/briefs/:id/content
#   El .md tal cual se guardó (text/markdown). Aparte porque puede pesar 1 MB y la
#   pantalla casi nunca lo necesita.
#
# Aparte de AssistantController, que ya está en su tope de largo. Mismo permiso: el
# encargo decide cómo le va a contestar el bot a los clientes, y puede traer
# material interno.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantBriefsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_brief, only: [:show, :content, :digest, :compose, :cover]

  def show
    render json: payload(@brief)
  end

  def create
    intake(params[:file])
  end

  def from_instructions
    nombre = File.basename(params[:filename].presence || 'instrucciones_iniciales.md')
    intake(ContactTrackings::Assistant::BriefIntake::TextUpload.new(params[:content].to_s, nombre))
  end

  def digest
    return render json: @brief.summary if @brief.ready?

    enqueue_digest(@brief)
    render json: @brief.summary, status: :accepted
  end

  def compose
    return render json: { error: 'not_ready' }, status: :unprocessable_entity unless @brief.ready?

    respuestas = params[:answers].respond_to?(:to_unsafe_h) ? params[:answers].to_unsafe_h : {}
    @brief.update!(answers: respuestas)
    inventario = ContactTrackings::Assistant::InventoryService.new(Current.account).call
    render json: ContactTrackings::Assistant::BriefComposer.new(@brief, answers: respuestas, inventory: inventario).call
  end

  def cover
    return render json: { error: 'not_ready' }, status: :unprocessable_entity unless @brief.ready?

    render json: ContactTrackings::Assistant::BriefCoverage
      .new(params[:draft], ficha: @brief.digest['ficha'], answers: @brief.answers).call
  end

  def content
    send_data @brief.content, filename: @brief.filename, type: 'text/markdown; charset=utf-8', disposition: 'inline'
  end

  private

  def intake(archivo)
    return render json: { error: 'session_not_found' }, status: :not_found if params[:session_id].present? && assistant_session.nil?

    result = ContactTrackings::Assistant::BriefIntake
             .new(Current.account, Current.user, file: archivo, session: assistant_session).call
    return render json: { error: result.error }, status: :unprocessable_entity if result.error

    enqueue_digest(result.brief)
    # Con la ficha si ya viene leída (copiada de otro encargo con el mismo archivo):
    # sin ella, la pantalla mostraba "listo" con la ficha vacía (23/09).
    render json: payload(result.brief).merge(reused: result.reused).compact,
           status: result.reused == 'same_session' ? :ok : :created
  end

  def payload(brief)
    brief.summary.merge(brief.ready? ? { digest: brief.digest, usage: brief.usage } : {})
  end

  def enqueue_digest(brief)
    return if brief.ready?

    turno = params[:turn_id].to_s.match?(ContactTrackings::Assistant::TurnProgress::TURN_ID_RE) ? params[:turn_id] : nil
    ContactTrackings::Assistant::AgentBriefDigestJob.perform_later(brief.id, Current.user.id, turno)
  end

  # De la cuenta, no de quien pregunta: igual que las conversaciones del Asistente,
  # el encargo es trabajo del equipo de administradores.
  def fetch_brief
    @brief = TrackingAgentBrief.find_by(id: params[:id], account: Current.account)
    render json: { error: 'not_found' }, status: :not_found if @brief.nil?
  end

  def assistant_session
    return nil if params[:session_id].blank?

    @assistant_session ||= TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account)
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
