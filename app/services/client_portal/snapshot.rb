# frozen_string_literal: true

# Portal del cliente — lo que ve una organización (o contacto) en su enlace:
#   needs:    sus tareas pendientes («Lo que necesitamos de ti»), la más urgente primero
#   cases:    casos y proyectos abiertos (y los cerrados en los últimos 30 días) con sus
#             tareas visibles; en proyectos, avance, fases (la actual marcada), hitos y
#             casos hijos
class ClientPortal::Snapshot
  RECENT = 30.days
  CASE_LIMIT = 50

  def initialize(link)
    @link = link
  end

  def cases
    @cases ||= @link.cases.where.not(status: :cancelled)
                    .where('case_tickets.status NOT IN (:closed) OR case_tickets.updated_at > :since',
                           closed: [CaseTicket.statuses[:closed]], since: RECENT.ago)
                    .includes(:case_type, :case_type_column, :assignee)
                    .order(updated_at: :desc).limit(CASE_LIMIT).to_a
  end

  def tasks_by_case
    @tasks_by_case ||= CaseTask.where(case_ticket_id: cases.map(&:id)).client_facing.where.not(status: :cancelled)
                               .includes(:case_type_column, :completed_by_contact, client_entries: [:contact, :user, { file_attachment: :blob }])
                               .order(:position, :id).group_by(&:case_ticket_id)
  end

  def needs
    tasks_by_case.values.flatten.select { |t| t.for_client? && t.pending? }
                 .sort_by { |t| [t.due_at || 100.years.from_now, t.id] }
  end

  def tasks_for(ticket)
    tasks_by_case[ticket.id] || []
  end

  # Fases del proyecto: las columnas de trabajo de su tipo (sin las de espera ni las de
  # cierre), con la actual —por su columna o por su estado— y las que ya pasó.
  NOT_PHASES = %w[waiting_on_customer waiting_on_third_party waiting_on_internal closed cancelled].freeze

  def stages(ticket)
    columns = phase_columns(ticket)
    current = columns.index { |c| c.id == ticket.case_type_column_id } ||
              columns.index { |c| Array(c.statuses).include?(ticket.status) }
    columns.each_with_index.map do |column, i|
      { label: column.label, state: stage_state(i, current) }
    end
  end

  def phase_columns(ticket)
    return [] unless ticket.case_type

    ticket.case_type.case_type_columns.where(outcome: nil).order(:position).to_a
          .reject { |c| c.statuses.present? && (c.statuses - NOT_PHASES).empty? }
  end

  def project_children(ticket)
    ticket.project_children.includes(:case_type).order(:created_at).to_a
  end

  private

  def stage_state(index, current)
    return 'pending' if current.nil?
    return 'done' if index < current

    index == current ? 'current' : 'pending'
  end
end
