# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tasks
#
#  id                          :bigint           not null, primary key
#  cancel_reason               :string
#  cancelled_at                :datetime
#  completed_at                :datetime
#  description                 :text
#  due_at                      :datetime
#  estimated_minutes           :integer
#  focus_position              :integer
#  focused_at                  :datetime
#  milestone                   :boolean          default(FALSE), not null
#  planned_on                  :date
#  position                    :integer          default(0), not null
#  priority                    :integer          default("medium"), not null
#  required                    :boolean          default(FALSE), not null
#  sequence                    :integer
#  status                      :integer          default("pending"), not null
#  title                       :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  assignee_id                 :bigint
#  case_ticket_id              :bigint
#  case_type_column_id         :bigint
#  case_type_column_task_id    :bigint
#  completed_by_id             :bigint
#  contact_id                  :bigint
#  documentation_for_column_id :bigint
#  organization_id             :bigint
#  requester_id                :bigint
#  team_id                     :bigint
#
# Indexes
#
#  index_case_tasks_on_account_id                   (account_id)
#  index_case_tasks_on_account_id_and_priority      (account_id,priority)
#  index_case_tasks_on_assignee_id                  (assignee_id)
#  index_case_tasks_on_assignee_id_and_planned_on   (assignee_id,planned_on)
#  index_case_tasks_on_case_ticket_id               (case_ticket_id)
#  index_case_tasks_on_case_ticket_id_and_position  (case_ticket_id,position)
#  index_case_tasks_on_case_ticket_id_and_sequence  (case_ticket_id,sequence)
#  index_case_tasks_on_completed_by_id              (completed_by_id)
#  index_case_tasks_on_contact_id                   (contact_id)
#  index_case_tasks_on_organization_id              (organization_id)
#  index_case_tasks_on_requester_id                 (requester_id)
#  index_case_tasks_on_ticket_and_template          (case_ticket_id,case_type_column_task_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id) ON DELETE => nullify
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#  fk_rails_...  (case_type_column_id => case_type_columns.id) ON DELETE => nullify
#  fk_rails_...  (case_type_column_task_id => case_type_column_tasks.id) ON DELETE => nullify
#  fk_rails_...  (completed_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (documentation_for_column_id => case_type_columns.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => nullify
#  fk_rails_...  (requester_id => users.id) ON DELETE => nullify
#

# @tickets_cases — Tarea/subtarea de un ticket (osTicket "Tasks").
class CaseTask < ApplicationRecord
  belongs_to :account
  # Plan-Agenda — sin caso es una tarea de captura rápida.
  belongs_to :case_ticket, optional: true
  include AgendaLink
  include TaskReportable
  include CaseTaskActivity # Plan Actividad del caso
  belongs_to :assignee, class_name: 'User', optional: true
  # @tickets_cases — solicitante: quién dio de alta la tarea. Se fija al crear con
  # el agente actual y no se edita desde la UI (a diferencia del responsable).
  belongs_to :requester, class_name: 'User', optional: true
  # @tickets_cases P4 — quién marcó la tarea como completada (osTicket lo audita).
  belongs_to :completed_by, class_name: 'User', optional: true
  # @tickets_cases F0 — reuniones agendadas para esta tarea. Borrar la tarea NO
  # borra la reunión: vuelve a ser del ticket (:nullify, igual que las notas).
  has_many :case_meetings, dependent: :nullify
  has_many :case_meeting_series, class_name: 'CaseMeetingSeries', dependent: :nullify, inverse_of: :case_task
  # Plan-Plantilla-Tareas-Etapa — la tarea nació de la plantilla de una etapa.
  belongs_to :case_type_column_task, optional: true
  belongs_to :case_type_column, optional: true
  belongs_to :team, optional: true
  # T3 — la tarea «Documenta…» lleva a esta etapa; se completa sola, no a mano.
  belongs_to :documentation_for_column, class_name: 'CaseTypeColumn', optional: true
  # Tareas con el cliente — quién la hace: internal (como siempre), visible (nosotros; el
  # cliente ve el avance en su portal) o client (la trabaja el cliente en su portal).
  enum audience: { internal: 0, visible: 1, client: 2 }, _prefix: :for
  CLIENT_STATUSES = %w[in_progress].freeze # avance del cliente mientras sigue pendiente
  belongs_to :completed_by_contact, class_name: 'Contact', optional: true
  has_many :client_entries, class_name: 'CaseTaskClientEntry', dependent: :destroy
  scope :client_facing, -> { where(audience: %i[visible client]) }
  validates :client_status, inclusion: { in: CLIENT_STATUSES }, allow_nil: true
  validate :client_task_needs_case
  before_validation :client_task_rules

  # Valores nuevos SIEMPRE al final. `cancelled`: su caso se cerró (Cases::PendingTasksOnClose).
  enum status: { pending: 0, done: 1, cancelled: 2 }
  # @tickets_cases — prioridad propia de la tarea: NO se hereda del ticket ni se
  # deriva de impacto/urgencia como en CaseTicket. Mismos valores para que la UI
  # comparta etiquetas y colores. Con prefijo para que `low`/`high` no se
  # confundan con los de la prioridad del ticket al leer el código.
  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }, _prefix: :priority

  validates :title, presence: true, length: { maximum: 255 }
  validates :priority, presence: true
  # Plan-Bandeja-Prioridad F1 — duración estimada (min), opcional; máx. un día.
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1440 },
                                allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  def concluded?
    done?
  end

  # La orden de trabajo ya cierra con su reporte de servicio y firma: su lista de
  # verificación no lleva un reporte por punto.
  # Tampoco las del cliente: lo que hizo queda en sus entradas del portal.
  def report_required?
    !case_ticket&.work_order? && !for_client?
  end

  def report_ready?
    !report_required? || super
  end

  # @tickets_cases P4 — el "quién/cuándo" se deriva del cambio de estado, no se
  # acepta del cliente: así no hay forma de falsear la firma desde la API.
  before_save :track_completion, if: :will_save_change_to_status?
  # @tickets_cases — consecutivo estable por ticket (T001, T002…): se asigna al
  # crear y no se recicla al borrar. No lo acepta del cliente.
  before_create :assign_sequence
  # Plan-Plantilla-Tareas-Etapa T3 — terminar (o quitar) una obligatoria puede dejar
  # lista la etapa: sugerir o pasar a la siguiente, según su modo.
  after_commit :check_stage_advance, on: %i[update destroy],
                                     if: lambda {
                                       saved_change_to_required? ||
                                         (required? && (destroyed? || saved_change_to_status?))
                                     }

  private

  def check_stage_advance
    ticket = CaseTicket.find_by(id: case_ticket_id)
    Cases::StageAdvance.new(ticket).call if ticket
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] avance de etapa por la tarea #{id}: #{e.message}")
  end

  def assign_sequence
    siblings = case_ticket ? case_ticket.case_tasks : self.class.without_case.where(account_id: account_id)
    self.sequence = (siblings.maximum(:sequence) || 0) + 1
  end

  def track_completion
    if done?
      self.completed_at    = Time.current
      self.completed_by_id = Current.user&.id
    else
      self.completed_at    = nil
      self.completed_by_id = nil
    end
  end

  # Tareas con el cliente: las del cliente no tienen responsable interno (las sigue el
  # responsable del caso) y su avance solo vale mientras está pendiente.
  def client_task_rules
    clear_cancellation unless cancelled?
    self.assignee_id = nil if for_client?
    self.client_status = nil unless pending? && for_client?
    self.completed_by_contact_id = nil unless done?
  end

  # Reabrir una tarea cancelada (o completarla) quita su motivo de cancelación.
  def clear_cancellation
    self.cancelled_at = nil
    self.cancel_reason = nil
  end

  def client_task_needs_case
    errors.add(:audience, 'necesita un caso') if !for_internal? && case_ticket_id.nil?
  end
end
