# frozen_string_literal: true

# Probador de agentes — corre un lote contra un agente (una plática de prueba por caso, con el
# motor real en el canal de pruebas) y guarda el resultado en la corrida.
#
# Una prueba por ejecución: corre la siguiente que no tiene resultado, la guarda y se vuelve a
# encolar. Así
#   - un error en una prueba queda como resultado de ESA prueba (con su motivo) y siguen las demás;
#   - la corrida avanza a la vista («Corriendo 2 de 5») y no ocupa un hilo de Sidekiq por minutos;
#   - si Sidekiq se reinicia a media corrida, al volver retoma en la prueba que iba (las que ya
#     tienen resultado no se repiten). Si nunca vuelve, AgentTester::StaleRunsJob la cierra.
class AgentTester::RunJob < ApplicationJob
  queue_as :low

  def perform(run_id)
    run = AgentTestRun.find_by(id: run_id)
    return if run.nil? || run.finished?

    cases = cases_of(run).order(:id).to_a
    run.update!(status: 'running', total: cases.size) if run.status == 'queued'
    pending = cases.find { |test_case| run.case_done_ids.exclude?(test_case.id) }
    return finish(run) unless pending

    run.record!(result_for(run, pending))
    self.class.perform_later(run.id)
  end

  private

  def cases_of(run) = run.case_ids.present? ? AgentTestCase.where(id: run.case_ids) : run.batch.cases

  # Siempre con el case_id de la prueba que se corrió: es lo que marca qué falta (sin él, se repetiría).
  def result_for(run, test_case)
    AgentTester::ConversationRunner.new(run.tracking_template, user: run.created_by, seleccion: run.seleccion)
                                   .run(test_case).merge(case_id: test_case.id)
  rescue StandardError => e
    Rails.logger.error("[AgentTester::RunJob] corrida #{run.id}, prueba #{test_case.id}: #{e.class}: #{e.message}")
    { case_id: test_case.id, name: test_case.name, ok: false, reply: '', trace: nil,
      reason: "No se pudo correr esta prueba (#{e.class.name.demodulize}). Las demás siguieron." }
  end

  def finish(run)
    run.update!(status: 'done', finished_at: Time.current)
    AgentTestLog.finish_retests(run)
  end
end
