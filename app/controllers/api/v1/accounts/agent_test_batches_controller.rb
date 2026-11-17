# frozen_string_literal: true

# Probador de agentes — lotes de pruebas y sus corridas.
# GET    /agent_test_batches?template_id=            lotes (los más recientes primero) con sus pruebas y la última corrida
# POST   /agent_test_batches/run_corrections         { template_id } corre todas las correcciones de ese agente
# POST   /agent_test_batches                         { name }
# PATCH  /agent_test_batches/:id                     { name }
# DELETE /agent_test_batches/:id
# POST   /agent_test_batches/:id/cases               { name, messages: [], expected }
# PATCH  /agent_test_batches/:id/cases/:case_id
# DELETE /agent_test_batches/:id/cases/:case_id
# POST   /agent_test_batches/:id/run                 { template_id } → corrida (corre en segundo plano)
# GET    /agent_test_batches/runs                    bitácora de corridas; GET …/runs/:run_id una corrida
class Api::V1::Accounts::AgentTestBatchesController < Api::V1::Accounts::BaseController
  before_action :require_writer
  before_action :set_batch, only: %i[update destroy add_case update_case remove_case run]

  def index
    scope = batches.includes(:cases, :tracking_template).order(created_at: :desc)
    scope = scope.where(tracking_template_id: params[:template_id]) if params[:template_id].present?
    render json: scope.limit(200).map { |b| batch_json(b) }
  end

  def run_corrections
    template = Current.account.tracking_templates.find(params[:template_id])
    run = AgentTester::AutoCase.run_all(template, user: current_user)
    return render json: { error: 'Ese agente todavía no tiene correcciones.' }, status: :unprocessable_entity unless run

    render json: run_json(run), status: :accepted
  end

  def create
    batch = batches.create!(name: params[:name].to_s.strip.first(120), created_by: current_user)
    render json: batch_json(batch), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    @batch.update!(name: params[:name].to_s.strip.first(120))
    render json: batch_json(@batch)
  end

  def destroy
    @batch.destroy!
    head :ok
  end

  def add_case
    test_case = @batch.cases.create!(case_params.merge(account: Current.account))
    render json: case_json(test_case), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update_case
    test_case = @batch.cases.find(params[:case_id])
    test_case.update!(case_params)
    render json: case_json(test_case)
  end

  def remove_case
    @batch.cases.find(params[:case_id]).destroy!
    head :ok
  end

  def run
    template = Current.account.tracking_templates.find(params[:template_id])
    return render json: { error: 'El lote no tiene pruebas.' }, status: :unprocessable_entity if @batch.cases.empty?

    run = @batch.runs.create!(account: Current.account, tracking_template: template, created_by: current_user,
                              total: @batch.cases.count)
    AgentTester::RunJob.perform_later(run.id)
    render json: run_json(run), status: :accepted
  end

  def runs
    scope = AgentTestRun.where(account_id: Current.account.id).includes(:batch, :tracking_template).order(created_at: :desc)
    return render json: run_json(scope.find(params[:run_id]), full: true) if params[:run_id]

    render json: scope.limit(100).map { |r| run_json(r) }
  end

  private

  def require_writer
    render_access_denied unless access_grant.writable?('ai_agents')
  end

  def batches = AgentTestBatch.where(account_id: Current.account.id)

  def set_batch
    @batch = batches.find(params[:id])
  end

  def case_params
    { name: params[:name].to_s.strip.first(120).presence || 'Prueba',
      messages: Array(params[:messages]).map { |m| m.to_s.strip.first(1000) }.compact_blank.first(AgentTestCase::MAX_MESSAGES),
      expected: params[:expected].to_s.strip.first(2000) }
  end

  def batch_json(batch)
    last = batch.runs.order(created_at: :desc).first
    { id: batch.id, name: batch.name, day: batch.day, template_id: batch.tracking_template_id,
      cases: batch.cases.sort_by(&:id).map { |c| case_json(c) }, last_run: last && run_json(last) }
  end

  def case_json(test_case) = test_case.slice(:id, :name, :messages, :expected)

  def run_json(run, full: false)
    json = { id: run.id, batch_id: run.agent_test_batch_id, batch: run.label.presence || run.batch&.name, agent: run.tracking_template&.name,
             engine: run.tracking_template&.engine, status: run.status, total: run.total, passed: run.passed,
             created_at: run.created_at, finished_at: run.finished_at }
    full ? json.merge(results: run.results) : json
  end
end
