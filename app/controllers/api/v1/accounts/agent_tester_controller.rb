# frozen_string_literal: true

# Probador de agentes (Agentes IA › Probador) — probar un agente 1.0 o 2.0 como cliente, en el
# canal de pruebas, con el motor real; con 👎 el entrenador dice si el error es del prompt, del
# contenido, del modelo o del motor.
# GET  /agent_tester/agents                              agentes «En prueba» (con su motor)
# POST /agent_tester/agents/:template_id/testing         { on } prende o apaga «En prueba» (quien cambia agentes)
# POST /agent_tester/sessions                            { template_id } → plática nueva
# GET  /agent_tester/sessions/:conversation_id?after=    lo que contestó el agente después de ese mensaje
# POST /agent_tester/sessions/:conversation_id/say       { content } → mensaje del cliente
# POST /agent_tester/sessions/:conversation_id/feedback  👎 { message_id, feedback } → lo que dice el entrenador
# POST /agent_tester/sessions/:conversation_id/save_case { expected } guarda la plática como prueba (va sola
#                                                       al lote del agente y del día)
# POST /agent_tester/apply                               { log_id } aplica la corrección de prompt (2.0)
# POST /agent_tester/fix_source                          { canned_id, content } corrige una respuesta predefinida
# GET  /agent_tester/logs                                bitácora de correcciones (cada quien las suyas; quien
#                                                       cambia agentes, todas)
# POST /agent_tester/logs/:id/retest                     «Ya lo corregí»: corre otra vez la prueba de ese 👎
# GET  /agent_tester/sessions/:conversation_id/history   la plática completa, para seguirla desde la bitácora
# Probar, dar 👎 y guardar pruebas: cualquier usuario de la cuenta (el probador está en Inicio).
# Aplicar correcciones, corregir fuentes, «En prueba» y la bitácora: quien puede cambiar agentes
# (área Agentes IA en «todo»).
class Api::V1::Accounts::AgentTesterController < Api::V1::Accounts::BaseController
  before_action :require_writer, only: %i[testing apply fix_source]
  before_action :set_conversation, only: %i[show history say feedback save_case]

  def agents
    list = Current.account.tracking_templates.where(archived_at: nil, testing: true).order(:name)
    render json: { agents: list.map { |t| { id: t.id, name: t.name, engine: t.engine, objective: t.objective } },
                   can_edit: access_grant.writable?('ai_agents') }
  end

  def testing
    template = Current.account.tracking_templates.find(params[:template_id])
    template.update_columns(testing: ActiveModel::Type::Boolean.new.cast(params[:on]) || false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    render json: { id: template.id, testing: template.testing }
  end

  def start
    template = Current.account.tracking_templates.find_by!(id: params[:template_id], testing: true)
    conversation = sandbox.start(template, user: current_user)
    return render json: { error: 'No se pudo asignar el agente a la plática de prueba.' }, status: :unprocessable_entity unless conversation

    render json: session_json(conversation, template)
  end

  def show
    tracking = sandbox.tracking_for(@conversation)
    render json: { messages: sandbox.since(@conversation, params[:after])
                                    .map { |m| m.merge(lines: AgentTester::Trace.lines(m[:trace], account: Current.account)) },
                   tracking_status: tracking&.status, outdated: outdated?(tracking) }
  end

  def history
    template = sandbox.tracking_for(@conversation)&.tracking_template
    return render json: { error: 'La plática ya no tiene agente.' }, status: :unprocessable_entity unless template

    messages = @conversation.messages.where(message_type: %i[incoming outgoing]).order(:id).map { |m| history_json(m) }
    render json: session_json(@conversation, template).merge(messages: messages)
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

  def save_case
    template = sandbox.tracking_for(@conversation)&.tracking_template
    turns = Motor2::Prompt.history(@conversation).map(&:stringify_keys)
    batch = template && AgentTester::AutoCase.add(template, messages: turns, expected: params[:expected].to_s.strip.first(2000),
                                                            origin: 'manual')
    return render json: { error: 'Escribe qué se espera y al menos un mensaje del cliente.' }, status: :unprocessable_entity unless batch

    render json: { saved_in: batch.name }
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
    render json: logs_scope.includes(:tracking_template, :user).order(created_at: :desc).limit(200).map { |l| log_json(l) }
  end

  # «Ya lo corregí»: la prueba que se guardó de ese 👎 se corre otra vez con el agente como está hoy
  # (plática nueva: en el 1.0 toma el Entrenamiento nuevo). Al terminar dice si quedó.
  def retest
    log = logs_scope.find(params[:id])
    test_case = log.agent_test_case
    return render json: { error: 'Este 👎 no guardó prueba: pruébalo a mano en una plática nueva.' }, status: :unprocessable_entity unless test_case

    run = test_case.batch.runs.create!(account: Current.account, tracking_template: log.tracking_template, created_by: current_user,
                                       total: 1, case_ids: [test_case.id], label: "Probar de nuevo · #{log.tracking_template&.name}")
    log.update!(status: 'retesting', retest: { 'run_id' => run.id })
    AgentTester::RunJob.perform_later(run.id)
    render json: log_json(log)
  end

  private

  def require_writer
    render_access_denied unless access_grant.writable?('ai_agents')
  end

  def sandbox = @sandbox ||= AgentTester::Sandbox.new(Current.account)

  def logs_scope
    scope = AgentTestLog.where(account_id: Current.account.id)
    access_grant.writable?('ai_agents') ? scope : scope.where(user_id: current_user.id)
  end

  # Cada quien sus pláticas; quien cambia agentes puede ver cualquiera (p. ej. desde la bitácora).
  def set_conversation
    scope = Current.account.conversations.where(inbox_id: sandbox.inbox.id)
    scope = scope.where("additional_attributes ->> 'agent_tester_user_id' = ?", current_user.id.to_s) unless access_grant.writable?('ai_agents')
    @conversation = scope.find(params[:conversation_id])
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

  def history_json(message)
    role = 'assistant'
    role = 'note' if message.private
    role = 'user' if message.incoming?
    { id: message.id, role: role, content: message.content.to_s,
      lines: AgentTester::Trace.lines(AgentTester::Trace.normalize(message.content_attributes.to_h), account: Current.account) }
  end

  def log_json(log)
    report = log.motor2_report_id && Motor2Report.find_by(id: log.motor2_report_id)
    { id: log.id, kind: log.kind, engine: log.engine, agent: log.tracking_template&.name, template_id: log.tracking_template_id, user: log.user&.name,
      feedback: log.feedback, reply: log.reply, diagnosis: log.diagnosis, created_at: log.created_at,
      report_status: report&.status, conversation_id: log.conversation_id, status: log.status, retest: log.retest,
      has_case: log.agent_test_case_id.present? }
  end
end
