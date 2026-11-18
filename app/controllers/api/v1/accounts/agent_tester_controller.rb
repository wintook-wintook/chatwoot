# frozen_string_literal: true

# Probador de agentes (Agentes IA › Probador) — probar un agente 1.0 o 2.0 como cliente, en el
# canal de pruebas, con el motor real; con 👎 el entrenador dice si el error es del prompt, del
# contenido, del modelo o del motor.
# GET  /agent_tester/agents                              agentes «En prueba» (con su motor)
# POST /agent_tester/agents/:template_id/testing         { on } prende o apaga «En prueba» (quien cambia agentes)
# POST /agent_tester/sessions                            { template_id, seleccion } → plática nueva (seleccion:
#                                                       'on' | 'off' fuerza la búsqueda de predefinidas solo en ella)
# GET  /agent_tester/sessions/:conversation_id?after=    lo que contestó el agente después de ese mensaje
# POST /agent_tester/sessions/:conversation_id/say       { content } → mensaje del cliente
# POST /agent_tester/sessions/:conversation_id/feedback  👎 { message_id, feedback («¿Qué debió responder?»), note
#                                                       («¿Qué estuvo mal?», opcional), now } → queda para revisión y
#                                                       el diagnóstico corre aparte; con now (solo quien cambia
#                                                       agentes: «Ver diagnóstico al momento») lo dice el entrenador ya
# POST /agent_tester/sessions/:conversation_id/good      👍 { message_id } → la respuesta queda como prueba a cuidar
# «Revisión» (la causa de cada 👎): Api::V1::Accounts::AgentTesterReviewsController.
# POST /agent_tester/sessions/:conversation_id/save_case { expected } guarda la plática como prueba (va sola
#                                                       al lote del agente y del día)
# POST /agent_tester/apply                               { log_id } aplica la corrección de prompt (2.0)
# POST /agent_tester/fix_source                          { canned_id, content } corrige una respuesta predefinida
#                                                       (422 con el motivo si pasa de los topes)
# POST /agent_tester/fix_kind                            { canned_id, kind } le cambia la categoría fija
# POST /agent_tester/fix_start                           { canned_id, text } agrega al inicio cómo lo pregunta el cliente
# GET  /agent_tester/logs                                bitácora de correcciones (cada quien las suyas; quien
#                                                       cambia agentes, todas)
# POST /agent_tester/logs/:id/retest                     «Ya lo corregí»: corre otra vez la prueba de ese 👎
# GET  /agent_tester/sessions/:conversation_id/history   la plática completa, para seguirla desde la bitácora
# Probar, dar 👎 y guardar pruebas: cualquier usuario de la cuenta (el probador está en Inicio).
# Aplicar correcciones, corregir fuentes, «En prueba» y la bitácora: quien puede cambiar agentes
# (área Agentes IA en «todo»).
class Api::V1::Accounts::AgentTesterController < Api::V1::Accounts::BaseController
  before_action :require_writer, only: %i[testing apply fix_source fix_kind fix_start]
  before_action :set_conversation, only: %i[show history say feedback good save_case]

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
    conversation = sandbox.start(template, user: current_user, seleccion: params[:seleccion].presence)
    return render json: { error: 'No se pudo asignar el agente a la plática de prueba.' }, status: :unprocessable_entity unless conversation

    render json: AgentTester::LogJson.session(conversation, template)
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

    messages = @conversation.messages.where(message_type: %i[incoming outgoing]).order(:id).map do |m|
      AgentTester::LogJson.message(m, Current.account)
    end
    render json: AgentTester::LogJson.session(@conversation, template).merge(messages: messages)
  end

  def say
    message = sandbox.say(@conversation, params[:content])
    render json: { message_id: message.id }
  end

  # Quien prueba solo dice qué debió responder: queda para revisión y la causa la ve quien revisa
  # (con now, quien cambia agentes la ve al momento).
  def feedback
    return unless (feedback = rated_message)
    return render json: { error: 'Escribe qué debió responder.' }, status: :unprocessable_entity if params[:feedback].to_s.strip.blank?

    input = AgentTester::FeedbackInput.for(@conversation, @message, feedback: params[:feedback].to_s.strip, note: params[:note])
    if diagnose_now?
      feedback.rate('down')
      return render json: AgentTester::Trainer.new(@template, user: current_user).call(**input)
    end

    render json: feedback.down(input)
  end

  # 👍: la respuesta estaba bien; queda como prueba «a cuidar» para ver si después se rompe.
  def good
    return unless (feedback = rated_message)

    render json: feedback.up
  end

  def save_case
    template = sandbox.tracking_for(@conversation)&.tracking_template
    turns = Motor2::Prompt.history(@conversation).map(&:stringify_keys)
    test_case = template && AgentTester::AutoCase.add(template, messages: turns, expected: params[:expected].to_s.strip.first(2000),
                                                                origin: 'manual', variables: sandbox.variables_for(@conversation))
    return render json: { error: 'Escribe qué se espera y al menos un mensaje del cliente.' }, status: :unprocessable_entity unless test_case

    render json: { saved_in: test_case.batch.name }
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
    save_canned(canned, content: params[:content].to_s.strip.first(10_000))
  end

  # proyecto@predefinidas_que_contestan: «Cambiar categoría» de la respuesta culpable (👎 «es de la
  # categoría»).
  def fix_kind
    canned = Current.account.canned_responses.find(params[:canned_id])
    return render json: { error: 'Categoría inválida.' }, status: :unprocessable_entity unless CannedResponse::KINDS.include?(params[:kind])

    save_canned(canned, kind: params[:kind])
  end

  # 👎 «es de la búsqueda»: agrega al inicio de la respuesta cómo lo pregunta el cliente (lo que propuso
  # el entrenador), para que la búsqueda la junte.
  def fix_start
    canned = Current.account.canned_responses.find(params[:canned_id])
    texto = params[:text].to_s.strip.first(500)
    return render json: { error: 'No hay nada que agregar.' }, status: :unprocessable_entity if texto.blank?

    save_canned(canned, content: "#{texto}\n\n#{canned.content}")
  end

  # Quien no cambia agentes ve sus 👎 y cómo van, sin el diagnóstico (eso es de quien revisa).
  def logs
    writer = access_grant.writable?('ai_agents')
    list = logs_scope.includes(:tracking_template, :user).order(created_at: :desc).limit(200)
    render json: list.map { |l| writer ? AgentTester::LogJson.call(l) : AgentTester::LogJson.tester(l) }
  end

  # «Ya lo corregí»: la prueba que se guardó de ese 👎 se corre otra vez con el agente como está hoy
  # (plática nueva: en el 1.0 toma el Entrenamiento nuevo). Al terminar dice si quedó.
  def retest
    log = logs_scope.find(params[:id])
    test_case = log.agent_test_case
    return render json: { error: 'Este 👎 no guardó prueba: pruébalo a mano en una plática nueva.' }, status: :unprocessable_entity unless test_case

    run = AgentTestRun.start!(batch: test_case.batch, template: log.tracking_template, user: current_user, case_ids: [test_case.id],
                              label: "Probar de nuevo · #{log.tracking_template&.name}")
    log.update!(status: 'retesting', retest: { 'run_id' => run.id })
    render json: AgentTester::LogJson.call(log)
  end

  private

  def diagnose_now? = access_grant.writable?('ai_agents') && ActiveModel::Type::Boolean.new.cast(params[:now])

  # El mensaje calificado y su AgentTester::Feedback (nil, ya contestado, si la plática no tiene agente).
  def rated_message
    @message = @conversation.messages.find(params[:message_id])
    @template = sandbox.tracking_for(@conversation)&.tracking_template
    return AgentTester::Feedback.new(@conversation, @message, template: @template, user: current_user) if @template

    render json: { error: 'La plática ya no tiene agente.' }, status: :unprocessable_entity
    nil
  end

  # Con los topes de las predefinidas (3,500 / 2,000): si no cabe se dice por qué, con la liga para
  # partirla en Catálogos › Respuestas Predefinidas (FixModal: «Arreglar con IA»).
  def save_canned(canned, attrs)
    if canned.update(attrs)
      render json: { ok: true, canned_id: canned.id, kind: canned.kind, agent_chars: canned.agent_chars }
    else
      render json: { error: canned.errors.full_messages.to_sentence, canned_id: canned.id, too_long: canned.errors.key?(:content) },
             status: :unprocessable_entity
    end
  end

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
    scope = sandbox.conversations
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
end
