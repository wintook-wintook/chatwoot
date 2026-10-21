# frozen_string_literal: true

# @tickets_cases — Plan-Bandeja-Prioridad F1: puntaje de urgencia de las tareas
# pendientes para «Mi día». Reglas fijas y explicables (no IA): cada factor que
# suma deja un motivo (`reasons`) que la UI muestra como etiqueta.
#
#   Cases::TaskPriorityScore.new(tasks, account: account).call
#   # => { task_id => { score: 91, reasons: [{ key: 'overdue', points: 46, days: 2 }, …] } }
#
# Las tareas deben venir con `case_ticket: :case_type` precargado. El contexto
# que no está en la tarea (proyecto padre, visitas de las órdenes) se consulta
# por lote, una vez para todas.
class Cases::TaskPriorityScore
  # Proyecto pesa más que SLA (decisión 2026-10-21). F3: cada cuenta puede
  # cambiarlos (CaseSetting#task_priority_weights). `urgent_score` no suma: es el
  # umbral del aviso «Nueva urgente».
  DEFAULT_WEIGHTS = {
    overdue: 40, overdue_per_day: 3, overdue_days_max: 20,
    due_today: 30, due_tomorrow: 15, due_week: 5,
    priority_urgent: 30, priority_high: 20, priority_medium: 10,
    project_overdue: 30, milestone: 10, project_due_soon: 10,
    sla_overdue: 25, sla_at_risk: 15, case_urgent: 15,
    visit_overdue: 15, visit_today: 10,
    close_soon: 10,
    age_per_day: 1, age_max: 10,
    planned_missed: 20,
    waiting: -15,
    urgent_score: 70
  }.freeze

  SOON_DAYS = 7

  def self.weights_for(account)
    setting = account&.case_setting
    setting ? setting.task_priority_weights_effective : DEFAULT_WEIGHTS
  end

  # `day`: el día LOCAL del agente («Mi día» lo manda el navegador); sin él, el
  # del servidor.
  def initialize(tasks, account:, now: Time.current, day: nil)
    @tasks = tasks.to_a
    @weights = self.class.weights_for(account)
    @now = now
    @today = day || now.to_date
  end

  def call
    @tasks.index_with { |task| score(task) }.transform_keys(&:id)
  end

  private

  attr_reader :weights, :now, :today

  def score(task)
    reasons = []
    add_due(reasons, task)
    add_priority(reasons, task)
    add_planned(reasons, task)
    add_case(reasons, task, task.case_ticket) if task.case_ticket
    add_age(reasons, task)
    { score: reasons.sum { |r| r[:points] }, reasons: reasons }
  end

  def add(reasons, key, points = weights[key], **extra)
    reasons << { key: key.to_s, points: points, **extra } if points.to_i != 0
  end

  # --- la tarea misma ---------------------------------------------------------

  def add_due(reasons, task)
    return unless task.due_at

    if task.due_at < now
      days = ((now - task.due_at) / 1.day).floor
      extra = [days * weights[:overdue_per_day], weights[:overdue_days_max]].min
      return add(reasons, :overdue, weights[:overdue] + extra, days: days)
    end

    add_upcoming(reasons, (task.due_at.to_date - today).to_i)
  end

  def add_upcoming(reasons, days_left)
    if days_left.zero? then add(reasons, :due_today)
    elsif days_left == 1 then add(reasons, :due_tomorrow)
    elsif days_left <= SOON_DAYS then add(reasons, :due_week, days: days_left)
    end
  end

  def add_priority(reasons, task)
    key = :"priority_#{task.priority}"
    add(reasons, key) if weights.key?(key)
  end

  # Se programó para un día que ya pasó y no se hizo: vuelve a competir, con
  # puntos extra para que no se pierda.
  def add_planned(reasons, task)
    return unless task.planned_on && task.planned_on < today

    add(reasons, :planned_missed, date: task.planned_on.iso8601)
  end

  def add_age(reasons, task)
    days = ((now - task.created_at) / 1.day).floor
    points = [days * weights[:age_per_day], weights[:age_max]].min
    add(reasons, :age, points, days: days) if points.positive?
  end

  # --- el caso de la tarea (por clase) ----------------------------------------

  def add_case(reasons, task, ticket)
    add_project(reasons, task, ticket)
    add_sla(reasons, ticket)
    add(reasons, :case_urgent) if ticket.urgent?
    add_visit(reasons, ticket) if ticket.work_order?
    add(reasons, :close_soon) if commercial_close_soon?(ticket)
    add(reasons, :waiting) if CaseTicket::WAITING_STATUSES.include?(ticket.status)
  end

  # La tarea es del proyecto o de un caso dentro de él.
  def add_project(reasons, task, ticket)
    project = ticket.project? ? ticket : parent_projects[ticket.id]
    add(reasons, :milestone) if task.milestone? && ticket.project?
    return unless project

    if project.project_overdue? then add(reasons, :project_overdue)
    elsif project_due_soon?(project) then add(reasons, :project_due_soon)
    end
  end

  def project_due_soon?(project)
    project.project_due_on.present? && (project.project_due_on - today).to_i <= SOON_DAYS &&
      CaseTicket::CLOSED_STATUSES.exclude?(project.status)
  end

  def add_sla(reasons, ticket)
    return unless ticket.class_capability?(:sla)

    add(reasons, :sla_overdue) if ticket.overdue?
    add(reasons, :sla_at_risk) if ticket.at_risk?
  end

  def add_visit(reasons, ticket)
    starts = visits[ticket.id] || []
    if starts.any? { |t| t < now }
      add(reasons, :visit_overdue)
    elsif starts.any? { |t| t.to_date == today }
      add(reasons, :visit_today)
    end
  end

  def commercial_close_soon?(ticket)
    ticket.commercial? && ticket.outcome.nil? && ticket.expected_close_at.present? &&
      (ticket.expected_close_at - today).to_i <= SOON_DAYS
  end

  # --- contexto por lote -------------------------------------------------------

  def tickets
    @tickets ||= @tasks.filter_map(&:case_ticket).uniq
  end

  # caso → proyecto que lo contiene.
  def parent_projects
    @parent_projects ||= CaseTicketRelation.project_member.where(ticket_id: tickets.map(&:id))
                                           .includes(related_ticket: :case_type)
                                           .to_h { |rel| [rel.ticket_id, rel.related_ticket] }
  end

  # orden → horas de sus visitas vigentes.
  def visits
    @visits ||= CaseMeeting.active.where(case_ticket_id: tickets.select(&:work_order?).map(&:id))
                           .pluck(:case_ticket_id, :starts_at)
                           .group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end
end
