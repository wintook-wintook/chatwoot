# == Schema Information
#
# Table name: case_time_entries
#
#  id             :bigint           not null, primary key
#  ended_at       :datetime
#  location       :jsonb            not null
#  minutes        :integer
#  note           :string
#  source         :integer          default("timer"), not null
#  started_at     :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  case_ticket_id :bigint           not null
#  user_id        :bigint
#
# Indexes
#
#  index_case_time_entries_on_account_id      (account_id)
#  index_case_time_entries_on_case_ticket_id  (case_ticket_id)
#  index_case_time_entries_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

# Plan-Trabajo-Campo R1 — tiempo trabajado en una orden: con el botón Iniciar /
# Terminar (`timer`), capturado a mano (`manual`) o por Llegué/Terminé en campo
# (`visit`, R2). Las horas reales de la orden son la suma.
class CaseTimeEntry < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket
  belongs_to :user, optional: true

  enum source: { timer: 0, manual: 1, visit: 2 }

  before_validation :compute_minutes
  after_commit :refresh_actual_hours

  validates :started_at, presence: true
  validate :ends_after_start

  scope :running, -> { where(ended_at: nil) }
  scope :ordered, -> { order(:started_at, :id) }

  private

  def compute_minutes
    self.minutes = ((ended_at - started_at) / 60).round if ended_at && started_at && (minutes.nil? || will_save_change_to_ended_at?)
  end

  def ends_after_start
    errors.add(:ended_at, 'debe ser después del inicio') if ended_at && started_at && ended_at < started_at
  end

  def refresh_actual_hours
    ticket = case_ticket
    return if ticket.nil? || ticket.destroyed?

    total = ticket.time_entries.sum(:minutes)
    ticket.update_columns(actual_hours: (total / 60.0).round(2)) # rubocop:disable Rails/SkipsModelValidations
  end
end
