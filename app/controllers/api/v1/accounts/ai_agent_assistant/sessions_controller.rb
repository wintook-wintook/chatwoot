# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Controlador: AiAgentAssistant::SessionsController
# Descripción: El chat asistente. Una sesión es una conversación con su borrador.
# Acciones: index, show, create (abre y da el primer turno), messages (un turno),
#           apply (mueve al borrador SOLO los campos aceptados), destroy
#
# El asistente nunca escribe en el Agente IA: el borrador vive en la sesión y el
# guardado lo hace el usuario desde el formulario de siempre.
# ================================================================================

class Api::V1::Accounts::AiAgentAssistant::SessionsController < Api::V1::Accounts::BaseController
  before_action :fetch_session, only: [:show, :messages, :apply, :destroy]

  def index
    sessions = Current.account.ai_agent_assistant_sessions.where(user: Current.user).recent.limit(20)
    render json: { sessions: sessions.map { |s| summary_json(s) } }
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
