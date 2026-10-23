# frozen_string_literal: true

# == Schema Information
#
# Table name: case_outcome_reasons
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  label      :string           not null
#  outcome    :integer          not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_case_outcome_reasons_on_account_id_and_outcome  (account_id,outcome)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class CaseOutcomeReason < ApplicationRecord
  belongs_to :account
  has_many   :case_tickets, foreign_key: :outcome_reason_id, dependent: :nullify, inverse_of: :outcome_reason
  has_many   :postponed_tickets, class_name: 'CaseTicket', foreign_key: :postpone_reason_id,
                                 dependent: :nullify, inverse_of: :postpone_reason

  # 0–2 = mismo mapeo que CaseTicket#outcome. `postponed` no es un resultado (la
  # pospuesta sigue abierta): solo existe en el catálogo. Valores nuevos SIEMPRE al
  # final (Trampa 17).
  enum outcome: { won: 0, lost: 1, cancelled: 2, postponed: 3 }, _prefix: :outcome

  validates :label, presence: true, length: { maximum: 100 }
  validates :outcome, presence: true

  scope :ordered, -> { order(:position, :id) }
  scope :enabled, -> { where(active: true) }

  DEFAULTS = {
    'won'       => ['Precio', 'Calidad del producto o servicio', 'Recomendación', 'Relación con el cliente', 'Otro'],
    'lost'      => ['Precio', 'Eligió a la competencia', 'Sin presupuesto', 'Sin respuesta del cliente', 'Otro'],
    'postponed' => ['Sin presupuesto por ahora', 'Esperando autorización', 'El cliente pidió contactarlo después',
                    'Fuera de temporada', 'Otro'],
    'cancelled' => ['El cliente desistió', 'Duplicada', 'Datos erróneos', 'Otro']
  }.freeze

  # Siembra los motivos por defecto de cada resultado que aún no tenga ninguno
  # (así una cuenta con perdida/cancelada ya configuradas recibe ganada/pospuesta).
  def self.ensure_defaults_for(account)
    seeded = account.case_outcome_reasons.distinct.pluck(:outcome)
    DEFAULTS.except(*seeded).each do |outcome, labels|
      labels.each_with_index do |label, position|
        account.case_outcome_reasons.create!(outcome: outcome, label: label, position: position)
      end
    end
    account.case_outcome_reasons.ordered
  end
end
