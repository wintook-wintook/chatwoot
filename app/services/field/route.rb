# Plan-Trabajo-Campo R2 — «Mi ruta de hoy»: las visitas del día del técnico.
# Una visita es una reunión (visita agendada) de una orden de trabajo en campo,
# que es suya (organizador o responsable de la orden). En orden de hora.
class Field::Route
  def initialize(scope, user, day)
    @scope = scope
    @user = user
    @day = day
  end

  def visits
    meetings.map do |meeting|
      order = meeting.case_ticket
      Field::VisitSerializer.new(order, @user).summary.merge(
        meeting: { id: meeting.id, title: meeting.title, starts_at: meeting.starts_at, ends_at: meeting.ends_at }
      )
    end
  end

  private

  def meetings
    orders = @scope.where(case_type_id: CaseType.where(case_class: :work_order).select(:id))
                   .where.not(status: %w[closed cancelled])
    CaseMeeting.active.where(case_ticket_id: orders.select(:id), starts_at: @day.all_day)
               .where('case_meetings.organizer_id = :me OR case_meetings.case_ticket_id IN (:mine)',
                      me: @user.id, mine: orders.where(assignee_id: @user.id).select(:id))
               .includes(case_ticket: %i[contact case_type])
               .order(:starts_at)
               .select { |meeting| meeting.case_ticket.on_site_effective }
  end
end
