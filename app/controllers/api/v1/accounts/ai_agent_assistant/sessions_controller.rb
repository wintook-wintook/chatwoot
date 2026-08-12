# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Controlador: AiAgentAssistant::SessionsController
# Descripción: El chat asistente. Una sesión es una conversación con su borrador.
# Acciones: index, show, create (abre y da el primer turno), update (cambia de modo
#           SIN perder la conversación ni el borrador), messages (un turno),
#           apply (mueve al borrador SOLO los campos aceptados), destroy
#
# El asistente nunca escribe en el Agente IA: el borrador vive en la sesión y el
# guardado lo hace el usuario desde el formulario de siempre.
# ================================================================================

class Api::V1::Accounts::AiAgentAssistant::SessionsController < Api::V1::Accounts::BaseController
  before_action :fetch_session, only: [:show, :update, :messages, :apply, :destroy]

  def index
    sessions = Current.account.ai_agent_assistant_sessions.where(user: Current.user).recent
    # El asistente del editor trabaja sobre un Agente IA concreto; el de la página, sobre
    # ninguno. Filtrar por eso es lo que permite retomar la conversación correcta.
    sessions = sessions.where(tracking_template_id: params[:tracking_template_id].presence)
    render json: { sessions: sessions.limit(20).map { |s| summary_json(s) } }
  end

  def show
    render json: session_json(@session)
  end

  # Abre la sesión y devuelve ya el primer turno: el asistente arranca preguntando,
  # no esperando. En modo auditar, el prompt pegado entra como borrador de partida.
  def create
    @session = Current.account.ai_agent_assistant_sessions.new(
      user: Current.user,
      mode: requested_mode,
      tracking_template_id: fetch_template&.id,
      step: AiAgentAssistant::Interview.first_step,
      draft: initial_draft
    )
    @session.save!

    render json: session_json(@session, run_turn), status: :created
  end

  # Cambiar de modo NO abre otra conversación: el borrador es el mismo agente y el
  # hilo anterior es contexto útil —auditar lo que acabas de armar en la entrevista
  # es justo el caso de uso—. Solo cambia el encuadre del siguiente turno.
  def update
    apply_mode_change if params[:mode].present?
    # El borrador también se edita a mano: hay campos —el nombre— que uno sabe y no
    # tiene sentido esperar a que el asistente los proponga.
    @session.draft = @session.draft.merge(editable_draft) if editable_draft.present?
    @session.save!

    render json: session_json(@session)
  end

  def messages
    render json: session_json(@session, run_turn(params[:message]))
  end

  # Aplicación POR CAMPO: el usuario elige qué acepta. Devuelve el diff de lo que
  # cambió en el borrador, para que se vea antes y después.
  def apply
    before  = @session.merged_draft
    applied = @session.apply_proposals!(params[:fields])

    render json: session_json(@session).merge(
      applied: applied.pluck('field'),
      diff: AiAgentAssistant::VersionDiff.between(before, @session.merged_draft)
    )
  end

  def destroy
    @session.destroy!
    head :ok
  end

  private

  def apply_mode_change
    @session.mode = requested_mode
    # Marca estructurada, no texto: la etiqueta la pone el frontend desde su i18n.
    @session.append_message('system', '', mode: @session.mode)
  end

  def editable_draft
    return @editable_draft if defined?(@editable_draft)

    raw = params[:draft]
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    @editable_draft = raw.is_a?(Hash) ? raw.stringify_keys.slice(*AiAgentAssistantSession::DRAFT_FIELDS) : {}
  end

  def fetch_session
    @session = Current.account.ai_agent_assistant_sessions.where(user: Current.user).find(params[:id])
  end

  def fetch_template
    return @fetch_template if defined?(@fetch_template)

    id = params[:tracking_template_id]
    @fetch_template = id.present? ? Current.account.tracking_templates.find_by(id: id) : nil
  end

  def requested_mode
    mode = params[:mode].to_s
    AiAgentAssistantSession::MODES.include?(mode) ? mode : 'interview'
  end

  # Modo auditar: el usuario llega con un prompt escrito fuera (normalmente en
  # ChatGPT, que no conoce este motor). Es el material a diseccionar.
  def initial_draft
    pasted = params[:complementary_prompt].to_s
    pasted.present? ? { 'complementary_prompt' => pasted } : {}
  end

  def run_turn(message = nil)
    AiAgentAssistant::ConversationService.new(@session).call(message)
  end

  def summary_json(session)
    { id: session.id, mode: session.mode, step: session.step,
      tracking_template_id: session.tracking_template_id,
      name: session.merged_draft['name'], updated_at: session.updated_at }
  end

  def session_json(session, turn = nil)
    summary_json(session).merge(
      messages: session.messages,
      draft: session.merged_draft,
      proposals: session.proposals,
      steps: AiAgentAssistant::Interview.steps.map { |s| s.slice(:key, :question) },
      turn: turn
    ).compact
  end
end
