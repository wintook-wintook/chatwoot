# frozen_string_literal: true

# Tareas que se repiten — una tarea fija que Kontrolya le vuelve a crear al responsable cada cierto tiempo.
#   mode 'fixed'       fecha fija en el calendario: cada N días/semanas (en ciertos días)/meses, la haya hecho o no.
#   mode 'after_done'  N días/semanas/meses después de la última vez que la hizo.
# Cada vez que toca, TaskRecurrences::Generator crea una tarea normal (con su reporte de cierre) o, con hora
# (at_time), una tarea agendada. Si la anterior sigue pendiente no se le amontona otra: cuenta como no hecha
# (missed_count) y se avisa (Notification task_recurrence_missed). Lo corre TaskRecurrences::RunJob cada hora.
class TaskRecurrence < ApplicationRecord
  MODES = %w[fixed after_done].freeze
  UNITS = %w[day week month].freeze
  STATUSES = %w[active paused ended].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :contact, optional: true
  belongs_to :organization, optional: true
  belongs_to :case_ticket, optional: true
  has_many :case_tasks, dependent: :nullify
  has_many :case_meetings, dependent: :nullify

  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }, _prefix: :priority

  validates :title, presence: true, length: { maximum: 255 }
  validates :mode, inclusion: { in: MODES }
  validates :unit, inclusion: { in: UNITS }
  validates :status, inclusion: { in: STATUSES }
  validates :every, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
  validates :max_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1440 }, allow_nil: true
  validates :at_time, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/ }, allow_blank: true
  validates :starts_on, presence: true
  validate :weekdays_in_range
  validate :ends_after_start

  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user_id) { where(assignee_id: user_id).or(where(user_id: user_id)) }

  def zone = ActiveSupport::TimeZone[time_zone.to_s] || Time.zone
  def today = Time.current.in_time_zone(zone).to_date
  def fixed? = mode == 'fixed'
  def scheduled? = at_time.present?
  def cadence = TaskRecurrences::Cadence.new(self)

  # La vez que sigue sin hacerse (tarea pendiente o agendada sin concluir).
  def pending_item
    case_tasks.pending.order(:id).last || case_meetings.where(status: :scheduled).order(:id).last
  end

  # Fecha de la última vez que la hizo (para 'after_done').
  def last_done_on
    done = [case_tasks.done.maximum(:completed_at), case_meetings.where(status: %i[held no_show]).maximum(:held_at)].compact.max
    done&.in_time_zone(zone)&.to_date
  end

  def push_event_data
    { id: id, title: title, next_on: next_on }
  end

  private

  def weekdays_in_range
    errors.add(:weekdays, :invalid) unless Array(weekdays).all? { |d| d.is_a?(Integer) && d.between?(0, 6) }
  end

  def ends_after_start
    errors.add(:ends_on, :invalid) if ends_on && starts_on && ends_on < starts_on
  end
end
