# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_test_runs
#
#  id                   :bigint           not null, primary key
#  case_ids             :jsonb            not null
#  error                :string
#  finished_at          :datetime
#  label                :string
#  passed               :integer          default(0), not null
#  results              :jsonb            not null
#  seleccion            :string
#  status               :string           default("queued"), not null
#  total                :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  agent_test_batch_id  :bigint           not null
#  created_by_id        :bigint
#  tracking_template_id :bigint           not null
#
# Indexes
#
#  index_agent_test_runs_on_account_id            (account_id)
#  index_agent_test_runs_on_agent_test_batch_id   (agent_test_batch_id)
#  index_agent_test_runs_on_created_by_id         (created_by_id)
#  index_agent_test_runs_on_tracking_template_id  (tracking_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (agent_test_batch_id => agent_test_batches.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#
class AgentTestRun < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  belongs_to :account
  belongs_to :batch, class_name: 'AgentTestBatch', foreign_key: :agent_test_batch_id, inverse_of: :runs
  belongs_to :tracking_template
  belongs_to :created_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
  # Con qué búsqueda de predefinidas corrió: nil = la de la cuenta; 'on' la nueva; 'off' la de siempre.
  SELECCIONES = %w[on off].freeze
  validates :seleccion, inclusion: { in: SELECCIONES }, allow_nil: true

  IN_PROGRESS = %w[queued running].freeze
  # Una prueba tarda como mucho ~14 min (8 mensajes × 100 s de espera + el juez). Sin avanzar más
  # que eso, la corrida se perdió (p. ej. Sidekiq se cayó y no volvió a tomarla).
  STALE_AFTER = 30.minutes
  STALE_REASON = 'La corrida se interrumpió (se reinició el servidor de tareas). Córrela de nuevo.'

  scope :in_progress, -> { where(status: IN_PROGRESS) }

  # La corrida nueva, o la que ya va con lo mismo (doble clic, o «Correr» otra vez porque no se veía
  # avanzar): no se encolan dos iguales.
  def self.start!(batch:, template:, user:, case_ids: [], label: nil, seleccion: nil) # rubocop:disable Metrics/ParameterLists
    seleccion = seleccion.presence_in(SELECCIONES)
    run = batch.runs.in_progress.where(tracking_template: template, seleccion: seleccion)
               .find_by('case_ids = ?::jsonb', Array(case_ids).to_json)
    return run if run

    run = batch.runs.create!(account: batch.account, tracking_template: template, created_by: user, case_ids: Array(case_ids),
                             label: label, total: case_ids.presence&.size || batch.cases.count, seleccion: seleccion)
    AgentTester::RunJob.perform_later(run.id)
    run
  end

  # Corridas que dejaron de avanzar: fallidas con su motivo, y sus «Probar de nuevo» terminan.
  def self.close_stale!
    in_progress.where('updated_at < ?', STALE_AFTER.ago).find_each do |run|
      run.update!(status: 'failed', finished_at: Time.current, error: STALE_REASON)
      AgentTestLog.finish_retests(run)
    end
  end

  def finished? = IN_PROGRESS.exclude?(status)

  def case_done_ids = Array(results).filter_map { |r| r['case_id']&.to_i }

  # Agrega el resultado de una prueba (con candado: lo leen la pantalla y el vigilante a la vez).
  def record!(result)
    with_lock do
      result = result.as_json
      next if case_done_ids.include?(result['case_id'].to_i)

      update!(results: Array(results) + [result], passed: passed + (result['ok'] ? 1 : 0))
    end
  end
end
