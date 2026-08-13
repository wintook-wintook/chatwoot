# frozen_string_literal: true

# == Schema Information
#
# Table name: case_meetings
#
#  id                     :bigint           not null, primary key
#  attendee_emails        :jsonb            not null
#  cancelled_at           :datetime
#  description            :text
#  ends_at                :datetime         not null
#  held_at                :datetime
#  location               :string
#  meeting_url            :string
#  notify_client          :boolean          default(TRUE), not null
#  reconciled_at          :datetime
#  sequence               :integer
#  starts_at              :datetime         not null
#  status                 :integer          default("scheduled"), not null
#  sync_error             :text
#  sync_status            :integer          default("pending"), not null
#  time_zone              :string
#  title                  :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  cancelled_by_id        :bigint
#  case_meeting_series_id :bigint
#  case_task_id           :bigint
#  case_ticket_id         :bigint           not null
#  google_calendar_id     :string
#  google_event_id        :string
#  held_by_id             :bigint
#  organizer_id           :bigint
#
# Indexes
#
#  index_case_meetings_on_account_id_and_starts_at      (account_id,starts_at)
#  index_case_meetings_on_case_task_id                  (case_task_id)
#  index_case_meetings_on_case_ticket_id_and_sequence   (case_ticket_id,sequence)
#  index_case_meetings_on_case_ticket_id_and_starts_at  (case_ticket_id,starts_at)
#  index_case_meetings_on_google_event_id               (google_event_id)
#  index_case_meetings_on_series_id                     (case_meeting_series_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (cancelled_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (case_meeting_series_id => case_meeting_series.id) ON DELETE => cascade
#  fk_rails_...  (case_task_id => case_tasks.id) ON DELETE => nullify
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#  fk_rails_...  (held_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (organizer_id => users.id) ON DELETE => nullify
#

# @tickets_cases F0 — Reunión de un ticket (ver §3.1 del plan).
#
# Puede ser suelta (`case_meeting_series_id` NULL) o una ocurrencia de una serie.
# Puede colgar del ticket o de una TAREA del ticket, igual que las notas internas.
#
# El espejo en Google Calendar (F3) llena `google_event_id` / `meeting_url`; hasta
# entonces —o si no hay Calendar conectado— la reunión vive en `local_only`, que
# es un estado válido y no un error.
class CaseMeeting < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket
  belongs_to :case_task, optional: true
  belongs_to :case_meeting_series, optional: true
  # Dueño del calendario donde vive el evento: reasignar el ticket NO lo mueve
  # (§8.7 del plan), por eso se persiste y se muestra en la fila.
  belongs_to :organizer,    class_name: 'User', optional: true
  belongs_to :cancelled_by, class_name: 'User', optional: true
  belongs_to :held_by,      class_name: 'User', optional: true

  enum status: { scheduled: 0, held: 1, no_show: 2, cancelled: 3, rescheduled: 4 }
  # `local_only` = existe solo en MGCI. Modo degradado válido de la Opción B.
  enum sync_status: { pending: 0, synced: 1, failed: 2, local_only: 3 }, _prefix: :sync

  validates :title, presence: true, length: { maximum: 255 }
  validates :starts_at, :ends_at, presence: true
  validate  :ends_after_starts
  validate  :task_belongs_to_ticket
  validate  :series_belongs_to_ticket

  scope :ordered, -> { order(:starts_at, :id) }
  scope :active,  -> { where(status: %i[scheduled rescheduled]) }

  # Folio de la reunión dentro del ticket: R001, R002…
  def folio
    format('R%03d', sequence.to_i)
  end

  # ¿Se pasó del vencimiento de su TAREA? (F6 §11.4)
  def past_task_due?
    case_task&.due_at.present? && starts_at.present? && starts_at > case_task.due_at
  end
  alias beyond_task_due? past_task_due?

  # ¿Y del compromiso con el CLIENTE (vencimiento efectivo del ticket)? Este es
  # el caso grave: ahí NO se ofrece mover nada, solo se señala — mover ese
  # vencimiento es una decisión con peso de política, y su camino es `escalate`.
  def beyond_ticket_due?
    due = case_ticket&.effective_due_at
    due.present? && starts_at.present? && starts_at > due
  end

  # Vencimiento que cubriría esta reunión, para la acción "mover el vencimiento
  # de la tarea": el fin de la reunión, no su inicio.
  def suggested_task_due_at
    ends_at || starts_at
  end

  # Igual que CaseTask#track_completion: el quién/cuándo de `held` y `cancelled`
  # se DERIVA del cambio de estado en un before_save, nunca se acepta del cliente.
  before_save :track_signatures, if: :will_save_change_to_status?
  # Consecutivo estable por ticket (R001, R002…): no se recicla al borrar.
  before_create :assign_sequence

  private

  def assign_sequence
    self.sequence = (case_ticket.case_meetings.maximum(:sequence) || 0) + 1
  end

  def track_signatures
    # `no_show` también cierra la reunión: se firma igual que `held` (quién la dio
    # por terminada), y ambos disparan la oferta de minuta en la UI.
    if held? || no_show?
      self.held_at    = Time.current
      self.held_by_id = Current.user&.id
    else
      self.held_at    = nil
      self.held_by_id = nil
    end

    if cancelled?
      self.cancelled_at    = Time.current
      self.cancelled_by_id = Current.user&.id
    else
      self.cancelled_at    = nil
      self.cancelled_by_id = nil
    end
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, 'debe ser posterior a la fecha de inicio')
  end

  def task_belongs_to_ticket
    return if case_task_id.blank? || case_task&.case_ticket_id == case_ticket_id

    errors.add(:case_task_id, 'no pertenece a este ticket')
  end

  def series_belongs_to_ticket
    return if case_meeting_series_id.blank? || case_meeting_series&.case_ticket_id == case_ticket_id

    errors.add(:case_meeting_series_id, 'no pertenece a este ticket')
  end
end
