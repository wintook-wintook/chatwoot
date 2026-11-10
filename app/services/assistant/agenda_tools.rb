# frozen_string_literal: true

# Asistente (Dali) — la agenda del usuario (my_agenda): tareas agendadas y tareas pendientes
# entre dos fechas, con las atrasadas. Se incluye en Assistant::Tools.
module Assistant::AgendaTools
  def tool_my_agenda(args)
    from = @zone.parse(args['from'].to_s)&.beginning_of_day || Time.current.beginning_of_day
    to = @zone.parse(args['to'].to_s)&.end_of_day || from.end_of_day
    { meetings: my_meetings(from..to), tasks: my_tasks(to), overdue_note: 'tasks incluye las atrasadas (vencimiento antes de hoy).' }
  end

  def my_meetings(range)
    @account.case_meetings.where(organizer_id: @user.id, starts_at: range).where.not(status: %i[cancelled rescheduled])
            .order(:starts_at).limit(30).map { |m| meeting_ref(m) }
  end

  def my_tasks(until_time)
    @account.case_tasks.pending.where(assignee_id: @user.id).where(due_at: ..until_time)
            .order(:due_at).limit(30).map { |t| task_ref(t) }
  end
end
