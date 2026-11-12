# frozen_string_literal: true

# Asistente (Dali) — la agenda (my_agenda) y las personas del equipo (team_members).
#
#   my_agenda      tareas agendadas y tareas pendientes entre dos fechas, con las atrasadas. De
#                  quien pregunta o, con user_id, de otra persona del equipo (solo si su rol ve
#                  la Agenda de todos, igual que «Día de:» en Mi día).
#   team_members   usuarios de la empresa por nombre o correo: «mi compañero Pedro», «el día de
#                  Ana», «asígnasela a Luis». Una persona del equipo no es un contacto.
# Se incluye en Assistant::Tools.
module Assistant::AgendaTools
  TEAM_LIMIT = 8

  def tool_my_agenda(args)
    person = agenda_person(args['user_id'])
    return person if person.is_a?(Hash)

    from = @zone.parse(args['from'].to_s)&.beginning_of_day || Time.current.beginning_of_day
    to = @zone.parse(args['to'].to_s)&.end_of_day || from.end_of_day
    { person: person == @user ? 'tú' : person.name, meetings: my_meetings(from..to, person), tasks: my_tasks(to, person),
      overdue_note: 'tasks incluye las atrasadas (vencimiento antes de hoy).' }
  end

  def tool_team_members(args)
    users = @account.users.order(:name)
    q = args['query'].to_s.strip
    if q.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      users = users.where('users.name ILIKE :q OR users.display_name ILIKE :q OR users.email ILIKE :q', q: like)
    end
    roles = @account.account_users.where(user_id: users.limit(TEAM_LIMIT).select(:id)).includes(:access_role).index_by(&:user_id)
    { team_members: users.limit(TEAM_LIMIT).map { |u| team_ref(u, roles[u.id]) } }
  end

  def my_meetings(range, person = @user)
    @account.case_meetings.where(organizer_id: person.id, starts_at: range).where.not(status: %i[cancelled rescheduled])
            .order(:starts_at).limit(30).map { |m| meeting_ref(m) }
  end

  def my_tasks(until_time, person = @user)
    @account.case_tasks.pending.where(assignee_id: person.id).where(due_at: ..until_time)
            .order(:due_at).limit(30).map { |t| task_ref(t) }
  end

  private

  # La persona de la agenda: quien pregunta, u otra del equipo si su rol ve la Agenda de todos.
  def agenda_person(user_id)
    return @user if user_id.blank? || user_id.to_i == @user.id
    return { error: 'Solo puedes ver tu propia agenda: tu rol ve solo lo suyo en Agenda.' } if @grant.own?(:agenda)

    @account.users.find_by(id: user_id) || { error: 'No encontré a esa persona en tu equipo.' }
  end

  def team_ref(user, account_user)
    role = account_user&.access_role&.key || account_user&.role # administrator, supervisor, seller, technician…
    { id: user.id, name: user.name, email: user.email, role: role, you: user.id == @user.id || nil }.compact
  end
end
