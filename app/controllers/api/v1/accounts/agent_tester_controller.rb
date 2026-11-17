# frozen_string_literal: true

# Probador de agentes (Agentes IA › Probador) — probar un agente 1.0 o 2.0 como cliente, en el
# canal de pruebas, con el motor real; con 👎 el entrenador dice si el error es del prompt, del
# contenido, del modelo o del motor.
# GET  /agent_tester/agents                              agentes que se pueden probar (con su motor)
# POST /agent_tester/sessions                            { template_id } → plática nueva
# GET  /agent_tester/sessions/:conversation_id?after=    lo que contestó el agente después de ese mensaje
# POST /agent_tester/sessions/:conversation_id/say       { content } → mensaje del cliente
# POST /agent_tester/sessions/:conversation_id/feedback  👎 { message_id, feedback } → lo que dice el entrenador
# POST /agent_tester/apply                               { log_id } aplica la corrección de prompt (2.0)
# POST /agent_tester/fix_source                          { canned_id, content } corrige una respuesta predefinida
# GET  /agent_tester/logs                                bitácora de correcciones
# Para quien puede cambiar agentes (área Agentes IA en «todo»).
class Api::V1::Accounts::AgentTesterController < Api::V1::Accounts::BaseController
  before_action :require_writer
  before_action :set_conversation, only: %i[show say feedback]

  def agents
    list = Current.account.tracking_templates.where(archived_at: nil).order(:name)
    render json: list.map { |t| { id: t.id, name: t.name, engine: t.engine, objective: t.objective } }
  end

  def start
    template = Current.account.tracking_templates.find(params[:template_id])
    conversation = sandbox.start(template, user: current_user)
    return render json: { error: 'No se pudo asignar el agente a la plática de prueba.' }, status: :unprocessable_entity unless conversation

    render json: session_json(conversation, template)
  end

  def show
    tracking = sandbox.tracking_for(@conversation)
    render json: { messages: sandbox.since(@conversation, params[:after]).map { |m| m.merge(lines: AgentTester::Trace.lines(m[:trace])) },
                   tracking_status: tracking&.status, outdated: outdated?(tracking) }
  end

  def say
    message = sandbox.say(@conversation, params[:content])
    render json: { message_id: message.id }
  end

  def feedback
    message = @conversation.messages.find(params[:message_id])
    template = sandbox.tracking_for(@conversation)&.tracking_template
    return render json: { error: 'La plática ya no tiene agente.' }, status: :unprocessable_entity unless template

    turns = Motor2::Prompt.history(@conversation, upto: message).map(&:stringify_keys)
    render json: AgentTester::Trainer.new(template, user: current_user)
                                     .call(messages: turns, reply: message.content, feedback: params[:feedback].to_s.first(2000),
                                           trace: AgentTester::Trace.normalize(message.content_attributes.to_h),
                                           conversation_id: @conversation.id, message_id: message.id)
  end

  # La corrección de prompt de un agente 2.0 la aplica el mismo usuario (con versión y pruebas).
  def apply
    log = AgentTestLog.find_by!(account_id: Current.account.id, id: params[:log_id], kind: 'prompt', engine: '2')
    cause = log.diagnosis['cause'].to_h.merge('kind' => 'agent')
    cause['field'] = cause['field'].presence_in(Motor2::Trainer::FIELDS) || 'instructions'
    result = Motor2::Trainer::AgentFix.new(log.tracking_template, current_user, cause).call
    render json: { message: result&.dig(:message) || { kind: 'error', text: 'No había nada que aplicar.' } }
  end

  def fix_source
    canned = Current.account.canned_responses.find(params[:canned_id])
    canned.update!(content: params[:content].to_s.strip.first(10_000))
    render json: { ok: true }
  end

  def logs
    list = AgentTestLog.where(account_id: Current.account.id).includes(:tracking_template, :user).order(created_at: :desc).limit(200)
    render json: list.map { |l| log_json(l) }
  end

  private

  def require_writer
    render_access_denied unless access_grant.writable?('ai_agents')
  end

  def sandbox = @sandbox ||= AgentTester::Sandbox.new(Current.account)

  def set_conversation
    @conversation = Current.account.conversations.where(inbox_id: sandbox.inbox.id).find(params[:conversation_id])
  end

  # El 1.0 guarda una copia del Entrenamiento en cada plática: si el agente cambió después de
  # abrirla, lo nuevo no se ve aquí hasta empezar otra.
  def outdated?(tracking)
    template = tracking&.tracking_template
    return false if template.nil? || Motor2.on?(template)

    tracking.raw_complementary_prompt.to_s != template.complementary_prompt.to_s
  end

  def session_json(conversation, template)
    { conversation_id: conversation.id, display_id: conversation.display_id, template_id: template.id, engine: template.engine,
      name: template.name, after: conversation.messages.maximum(:id).to_i }
  end

  def log_json(log)
    report = log.motor2_report_id && Motor2Report.find_by(id: log.motor2_report_id)
    { id: log.id, kind: log.kind, engine: log.engine, agent: log.tracking_template&.name, user: log.user&.name,
      feedback: log.feedback, reply: log.reply, diagnosis: log.diagnosis, created_at: log.created_at,
      report_status: report&.status, conversation_id: log.conversation_id }
  end
end
