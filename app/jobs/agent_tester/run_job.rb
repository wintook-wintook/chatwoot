# frozen_string_literal: true

# Probador de agentes — corre un lote completo contra un agente (una plática de prueba por caso,
# con el motor real en el canal de pruebas) y guarda el resultado en la corrida.
class AgentTester::RunJob < ApplicationJob
  queue_as :low

  def perform(run_id)
    run = AgentTestRun.find_by(id: run_id)
    return unless run

    cases = run.case_ids.present? ? AgentTestCase.where(id: run.case_ids) : run.batch.cases
    run.update!(status: 'running', total: cases.count)
    runner = AgentTester::ConversationRunner.new(run.tracking_template, user: run.created_by)
    cases.order(:id).each { |test_case| record(run, runner.run(test_case)) }
    run.update!(status: 'done', finished_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[AgentTester::RunJob] #{e.class}: #{e.message}")
    run&.update(status: 'failed', finished_at: Time.current)
  end

  private

  def record(run, result)
    run.update!(results: run.results + [result.as_json], passed: run.passed + (result[:ok] ? 1 : 0))
  end
end
