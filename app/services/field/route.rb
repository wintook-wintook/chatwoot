# Plan-Trabajo-Campo R2 — «Mi ruta de hoy»: las visitas del día, de técnicos y vendedores.
# Una visita es una reunión (visita agendada) de una orden de trabajo en campo,
# que es suya (organizador o responsable de la orden). En orden de hora.
class Field::Route
  # `zone`: la del usuario. El día se cuenta en su hora, no en la del servidor (UTC).
  def initialize(scope, user, day, zone = Time.zone)
    @scope = scope
    @user = user
    @hours = day.in_time_zone(zone).all_day
  end

  def visits
    (order_visits + agenda_visits).sort_by { |visit| visit[:meeting][:starts_at] }
  end

  private

  def order_visits
    meetings.map do |meeting|
      order = meeting.case_ticket
      Field::VisitSerializer.new(order, @user).summary.merge(
        kind: 'order', meeting: { id: meeting.id, title: meeting.title, starts_at: meeting.starts_at, ends_at: meeting.ends_at }
      )
    end
  end

  # Tareas agendadas marcadas como visita; las de una orden ya van arriba.
  def agenda_visits
    CaseMeeting.where(is_visit: true, organizer_id: @user.id, starts_at: @hours).where.not(status: %i[cancelled rescheduled])
               .includes(:contact, :organization, case_ticket: %i[contact organization case_type])
               .reject { |meeting| meeting.case_ticket&.work_order? }
               .map { |meeting| Field::AgendaVisitSerializer.new(meeting).summary }
  end

  def meetings
    orders = @scope.where(case_type_id: CaseType.where(case_class: :work_order).select(:id))
                   .where.not(status: %w[closed cancelled])
    CaseMeeting.active.where(case_ticket_id: orders.select(:id), starts_at: @hours)
               .where('case_meetings.organizer_id = :me OR case_meetings.case_ticket_id IN (:mine)',
                      me: @user.id, mine: orders.where(assignee_id: @user.id).select(:id))
               .includes(case_ticket: %i[contact case_type])
               .order(:starts_at)
               .select { |meeting| meeting.case_ticket.on_site_effective }
  end
end
