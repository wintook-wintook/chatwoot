# frozen_string_literal: true

# Motor 2.0 — lo que el entrenador no puede corregir (falta una habilidad o el motor no obedeció
# una indicación): le llega a Kontrolya (lista en Super Admin y correo) y al corregirse se le
# avisa a quien lo reportó.
class Motor2Report < ApplicationRecord
  KINDS = %w[missing_skill ignored].freeze
  STATUSES = %w[new reviewing fixed rejected].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :open_first, -> { order(Arel.sql("CASE status WHEN 'new' THEN 0 WHEN 'reviewing' THEN 1 ELSE 2 END"), created_at: :desc) }

  after_update_commit :announce_fixed, if: -> { saved_change_to_status? && status == 'fixed' }

  private

  # Al corregirse: se le avisa a quien lo reportó y se vuelven a correr las pruebas del agente.
  def announce_fixed
    update_column(:fixed_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    Motor2ReportMailer.with(report: self).fixed.deliver_later
    Motor2::RunTestsJob.perform_later(tracking_template_id) if tracking_template_id
    AgentTester::AutoCase.rerun(tracking_template, user: user) if tracking_template
  end
end
