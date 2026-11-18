# frozen_string_literal: true

# Probador de agentes › Revisión (quien puede cambiar agentes). Quien probó solo dijo qué debió
# responder; aquí se revisa la causa, plática por plática y mensaje por mensaje.
# GET  /agent_tester/review?template_id=&status=open|all  los 👎 por plática (open: lo pendiente)
# GET  /agent_tester/review/:conversation_id             la plática con sus 👍/👎 y diagnósticos
# POST /agent_tester/logs/:id/dismiss                    { reason } «No es error» (su prueba deja de correrse)
# POST /agent_tester/logs/:id/rediagnose                 { note } «Otro diagnóstico» con la nota de quien revisa
# POST /agent_tester/logs/retest_group                   { ids } «Probar de nuevo» de varios en una corrida
class Api::V1::Accounts::AgentTesterReviewsController < Api::V1::Accounts::BaseController
  before_action :require_writer

  def index
    logs = scope.includes(:tracking_template, :user).order(created_at: :desc).limit(500).to_a
    render json: { agents: agents, conversations: AgentTester::Review.group(logs).map { |g| group_json(g) } }
  end

  def show
    conversation = AgentTester::Sandbox.new(Current.account).conversations.find(params[:conversation_id])
    template = AgentTester::Sandbox.new(Current.account).tracking_for(conversation)&.tracking_template
    render json: (template ? AgentTester::LogJson.session(conversation, template) : {}).merge(messages: messages(conversation))
  end

  def dismiss
    log = logs.find(params[:id])
    log.update!(status: 'dismissed', dismissed_reason: params[:reason].to_s.strip.first(500).presence)
    drop_case(log)
    render json: AgentTester::LogJson.call(log)
  end

  def rediagnose
    log = logs.find(params[:id])
    log.update!(kind: 'pending', status: 'pending', diagnosis: {})
    AgentTester::DiagnoseJob.perform_later(log.id, params[:note].to_s.strip.first(2000).presence)
    render json: AgentTester::LogJson.call(log)
  end

  # Varios 👎 de la misma causa: una sola corrida por agente con sus pruebas; todos quedan «probando».
  def retest_group
    elegidos = logs.where(id: Array(params[:ids]).map(&:to_i)).where.not(agent_test_case_id: nil).includes(:agent_test_case).to_a
    return render json: { error: 'Ninguno guardó prueba.' }, status: :unprocessable_entity if elegidos.empty?

    runs = elegidos.group_by(&:tracking_template).map { |template, grupo| retest(template, grupo) }
    render json: { logs: elegidos.map { |l| AgentTester::LogJson.call(l) }, run_ids: runs.map(&:id) }
  end

  private

  def require_writer
    render_access_denied unless access_grant.writable?('ai_agents')
  end

  def logs = AgentTestLog.where(account_id: Current.account.id)

  def scope
    found = logs
    found = found.where(tracking_template_id: params[:template_id]) if params[:template_id].present?
    params[:status] == 'all' ? found : found.open_review
  end

  def agents
    logs.open_review.group(:tracking_template_id).count.filter_map do |id, n|
      template = Current.account.tracking_templates.find_by(id: id)
      template && { template_id: id, name: template.name, open: n }
    end
  end

  def group_json(group)
    group.except(:same_canned).merge(logs: group[:logs].map { |l| AgentTester::LogJson.call(l).merge(same_canned: group[:same_canned][l.id]) })
  end

  def messages(conversation)
    por_mensaje = logs.where(conversation_id: conversation.id).order(:id).group_by(&:message_id)
    conversation.messages.where(message_type: %i[incoming outgoing]).order(:id).map do |m|
      AgentTester::LogJson.message(m, Current.account)
                          .merge(rating: m.content_attributes.to_h['agent_tester_rating'],
                                 logs: Array(por_mensaje[m.id]).map { |l| AgentTester::LogJson.call(l) })
    end
  end

  def retest(template, grupo)
    run = AgentTestRun.start!(batch: grupo.first.agent_test_case.batch, template: template, user: current_user,
                              case_ids: grupo.map(&:agent_test_case_id).uniq, label: "Probar de nuevo · #{template&.name}")
    grupo.each { |log| log.update!(status: 'retesting', retest: { 'run_id' => run.id }) }
    run
  end

  # «No es error»: su prueba deja de correrse (si ningún otro 👎 la usa).
  def drop_case(log)
    test_case = log.agent_test_case
    return if test_case.nil? || AgentTestLog.where(agent_test_case_id: test_case.id).where.not(id: log.id).exists?

    log.update!(agent_test_case: nil)
    test_case.destroy!
  end
end
