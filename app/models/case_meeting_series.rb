# frozen_string_literal: true

# == Schema Information
#
# Table name: case_meeting_series
#
#  id                 :bigint           not null, primary key
#  by_day             :jsonb            not null
#  cancelled_at       :datetime
#  count              :integer
#  description        :text
#  ends_at            :datetime         not null
#  freq               :integer          default("weekly"), not null
#  interval           :integer          default(1), not null
#  recurrence_rule    :string
#  sequence           :integer
#  starts_at          :datetime         not null
#  sync_error         :text
#  sync_status        :integer          default("pending"), not null
#  time_zone          :string
#  title              :string           not null
#  until_at           :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  cancelled_by_id    :bigint
#  case_task_id       :bigint
#  case_ticket_id     :bigint           not null
#  google_calendar_id :string
#  google_event_id    :string
#  organizer_id       :bigint
#
# Indexes
#
#  index_case_meeting_series_on_account_id           (account_id)
#  index_case_meeting_series_on_case_task_id         (case_task_id)
#  index_case_meeting_series_on_google_event_id      (google_event_id)
#  index_case_meeting_series_on_ticket_and_sequence  (case_ticket_id,sequence)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (cancelled_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (case_task_id => case_tasks.id) ON DELETE => nullify
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#  fk_rails_...  (organizer_id => users.id) ON DELETE => nullify
#

# @tickets_cases F0 — Serie de reuniones de un ticket (ver §3.2 del plan).
#
# La serie NO es una reunión: es la regla de repetición + el id del evento
# recurrente MAESTRO en Google. Las ocurrencias concretas viven en `case_meetings`
# apuntando aquí con `case_meeting_series_id`.
#
# Regla dura: **no se permiten series infinitas**. O `until_at` o `count`, nunca
# los dos ni ninguno — si no, se generarían ocurrencias sin fin en BD.
class CaseMeetingSeries < ApplicationRecord
  # Tope duro de ocurrencias (§9 del plan): protege BD y cuota de la API.
  MAX_OCCURRENCES = 100

  belongs_to :account
  belongs_to :case_ticket
  # La serie puede colgar de una tarea del ticket; las ocurrencias lo heredan.
  belongs_to :case_task, optional: true
  # Dueño del calendario donde vive el evento maestro. Se persiste porque
  # reasignar el ticket NO mueve el evento (§8.7 del plan).
  belongs_to :organizer,    class_name: 'User', optional: true
  belongs_to :cancelled_by, class_name: 'User', optional: true

  has_many :case_meetings, dependent: :destroy

  enum freq: { daily: 0, weekly: 1, monthly: 2 }, _prefix: :freq
  # `local_only` NO es un error: es el modo degradado válido de la Opción B
  # (la cuenta no tiene el flag `google_calendar` o el agente no conectó Calendar).
  enum sync_status: { pending: 0, synced: 1, failed: 2, local_only: 3 }, _prefix: :sync

  validates :title, presence: true, length: { maximum: 255 }
  validates :starts_at, :ends_at, presence: true
  validates :interval, numericality: { only_integer: true, greater_than: 0 }
  validates :count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_OCCURRENCES },
                    allow_nil: true
  validate  :ends_after_starts
  validate  :finite_recurrence
  validate  :until_after_starts
  validate  :task_belongs_to_ticket

  scope :ordered, -> { order(:starts_at, :id) }

  # Folio de la serie dentro del ticket: S01, S02…
  def folio
    format('S%02d', sequence.to_i)
  end

  def cancelled?
    cancelled_at.present?
  end

  # Igual que en CaseTask#track_completion: el quién/cuándo se DERIVA del cambio,
  # nunca se acepta del cliente.
  def cancel!(actor: nil)
    update!(cancelled_at: Time.current, cancelled_by_id: actor&.id || Current.user&.id)
  end

  # Consecutivo estable por ticket: se asigna al crear y no se recicla al borrar.
  before_create :assign_sequence

  private

  def assign_sequence
    self.sequence = (case_ticket.case_meeting_series.maximum(:sequence) || 0) + 1
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, 'debe ser posterior a la fecha de inicio')
  end

  # `until_at` y `count` son mutuamente excluyentes, y al menos uno es obligatorio:
  # una serie infinita generaría ocurrencias sin fin en BD.
  def finite_recurrence
    if until_at.present? && count.present?
      errors.add(:base, 'La serie no puede tener fecha de fin y número de ocurrencias a la vez')
    elsif until_at.blank? && count.blank?
      errors.add(:base, 'La serie necesita una fecha de fin o un número de ocurrencias')
    end
  end

  def until_after_starts
    return if until_at.blank? || starts_at.blank?
    return if until_at > starts_at

    errors.add(:until_at, 'debe ser posterior a la primera ocurrencia')
  end

  # La tarea tiene que ser del MISMO ticket: si no, la serie aparecería en el
  # avance de un caso ajeno.
  def task_belongs_to_ticket
    return if case_task_id.blank? || case_task&.case_ticket_id == case_ticket_id

    errors.add(:case_task_id, 'no pertenece a este ticket')
  end
end
