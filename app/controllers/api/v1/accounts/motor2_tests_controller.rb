# frozen_string_literal: true

# Motor 2.0 — pruebas guardadas y el entrenador de un agente 2.0.
# GET    /motor2_agents/:motor2_agent_id/tests              las pruebas con su último resultado
# POST   /motor2_agents/:motor2_agent_id/tests              guardar la plática { name, turns, expected }
# DELETE /motor2_agents/:motor2_agent_id/tests/:id
# POST   /motor2_agents/:motor2_agent_id/tests/run          correr todas (o { test_id })
# POST   /motor2_agents/:motor2_agent_id/tests/correct      👎: { messages, reply, feedback, trace } → lo que dice el entrenador
# POST   /motor2_agents/:motor2_agent_id/tests/fix_source   arreglar una respuesta predefinida { canned_id, content }
# Solo administradores.
class Api::V1::Accounts::Motor2TestsController < Api::V1::Accounts::BaseController
  MAX_RUN = 15

  ROLES = %w[user assistant].freeze

  before_action :require_admin
  before_action :set_template

  def index
    render json: tests.order(created_at: :desc).map { |t| test_json(t) }
  end

  def create
    test = tests.create!(account: Current.account, name: params[:name].to_s.strip.first(120).presence || 'Prueba',
                         turns: turns_param(params[:turns]), expected: params[:expected].to_s.strip.first(2000),
                         origin: 'manual')
    render json: test_json(test), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    tests.find(params[:id]).destroy!
    head :ok
  end

  def run
    list = params[:test_id].present? ? tests.where(id: params[:test_id]) : tests.order(created_at: :desc).limit(MAX_RUN)
    runner = Motor2::TestRunner.new(@template)
    render json: list.map { |t| test_json(t.tap { |test| runner.run(test) }) }
  end

  def correct
    result = Motor2::Trainer.new(@template, user: current_user)
                            .call(messages: turns_param(params[:messages]), reply: params[:reply].to_s.first(4000),
                                  feedback: params[:feedback].to_s.first(2000), trace: plain(params[:trace]))
    render json: result
  end

  # Solo las predefinidas (son de la cuenta). Las usan también el equipo y otros agentes.
  def fix_source
    canned = Current.account.canned_responses.find(params[:canned_id])
    canned.update!(content: params[:content].to_s.strip.first(10_000))
    render json: { ok: true, short_code: canned.short_code }
  end

  private

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def set_template
    @template = Current.account.tracking_templates.find_by!(id: params[:motor2_agent_id], engine: Motor2::ENGINE)
  end

  def tests = Motor2Test.where(tracking_template_id: @template.id)

  def turns_param(raw)
    Array(raw).last(30).filter_map do |m|
      m = plain(m)
      { 'role' => m['role'], 'content' => m['content'].to_s.first(2000) } if ROLES.include?(m['role']) && m['content'].present?
    end
  end

  def plain(value) = Motor2::Sanitizer.plain(value)

  def test_json(test)
    { id: test.id, name: test.name, origin: test.origin, expected: test.expected, turns: test.turns, last_run: test.last_run,
      created_at: test.created_at }
  end
end
