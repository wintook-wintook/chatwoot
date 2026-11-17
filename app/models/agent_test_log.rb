# frozen_string_literal: true

# Probador de agentes — la bitácora de correcciones: cada 👎 con lo que dijo el usuario y dónde
# estuvo el error (prompt, contenido, modelo o motor). Los del motor llevan su reporte a
# Kontrolya (motor2_reports).
class AgentTestLog < ApplicationRecord
  KINDS = %w[prompt content search model engine question].freeze
  # Seguimiento de cada 👎: pendiente → «Ya lo corregí» corre su prueba otra vez → quedó / sigue fallando.
  STATUSES = %w[pending retesting passed failing].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :user, optional: true
  belongs_to :agent_test_case, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :engine, inclusion: { in: %w[1 2] }
  validates :status, inclusion: { in: STATUSES }

  # Al terminar la corrida de «Probar de nuevo»: quedó o sigue fallando, con lo que contestó.
  def self.finish_retests(run)
    where(account_id: run.account_id).where("retest ->> 'run_id' = ?", run.id.to_s).find_each do |log|
      result = Array(run.results).find { |r| r['case_id'].to_i == log.agent_test_case_id }
      ok = run.status == 'done' && result && result['ok']
      log.update!(status: ok ? 'passed' : 'failing',
                  retest: log.retest.merge('reply' => result&.dig('reply').to_s, 'at' => Time.current,
                                           'reason' => result&.dig('reason').presence || 'No se pudo correr la prueba.'))
    end
  end
end
