# == Schema Information
#
# Table name: task_outcomes
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  label      :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_task_outcomes_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class TaskOutcome < ApplicationRecord
  DEFAULTS = ['Logrado', 'No contestó', 'Reprogramar', 'No se pudo'].freeze
  # Motivos para cancelar una tarea o tarea agendada (purpose: cancel). «Otro» pide comentario.
  CANCEL_DEFAULTS = ['El cliente ya no lo necesita', 'Se resolvió de otra forma', 'Duplicada', 'Se reprogramó', 'Otro'].freeze
  OTHER = 'Otro'.freeze

  belongs_to :account

  validates :label, presence: true, length: { maximum: 100 }

  # report: resultado del reporte de cierre (como siempre) · cancel: motivo de cancelación.
  enum purpose: { report: 0, cancel: 1 }, _prefix: :for

  scope :ordered, -> { order(:position, :id) }

  def self.ensure_defaults_for(account, purpose: 'report')
    scope = account.task_outcomes.where(purpose: purpose)
    seed_defaults(account, purpose) if scope.none?
    scope.ordered
  end

  def self.seed_defaults(account, purpose = 'report')
    labels = purpose.to_s == 'cancel' ? CANCEL_DEFAULTS : DEFAULTS
    labels.each_with_index { |label, position| account.task_outcomes.create!(label: label, position: position, purpose: purpose) }
  end

  def other?
    label.to_s.strip.casecmp?(OTHER)
  end
end
