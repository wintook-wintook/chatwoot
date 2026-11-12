# frozen_string_literal: true

# Asistente (Dali) — la agenda (my_agenda) y las personas del equipo (team_members).
#
#   my_agenda      tareas agendadas y tareas pendientes entre dos fechas, con las atrasadas. De
#                  quien pregunta o, con user_id, de otra persona del equipo (solo si su rol ve
#                  la Agenda de todos, igual que «Día de:» en Mi día).
#                  Un solo día de ±1 de hoy = la MISMA consulta de la página Mi día
#                  (Cases::TasksInboxQuery mode my_day): citas agendadas, «Mi orden de hoy» y luego
#                  por prioridad, sin lo pasado a otro día; las primeras DAY_LIMIT y cuántas más.
#                  Varios días: citas agendadas del rango + tareas que vencen o se pasaron a un día
#                  del rango (las pasadas a un día fuera del rango no salen).
#   team_members   usuarios de la empresa por nombre o correo: «mi compañero Pedro», «el día de
#                  Ana», «asígnasela a Luis». Una persona del equipo no es un contacto.
# Se incluye en Assistant::Tools.
module Assistant::AgendaTools
  TEAM_LIMIT = 8
  DAY_LIMIT = 10

  def tool_my_agenda(args)
    person = agenda_person(args['user_id'])
    return person if person.is_a?(Hash)

    from, to = agenda_range(args)
    base = { person: person == @user ? 'tú' : person.name }
    return base.merge(my_day_like_page(from.to_date, person)) if page_day?(from, to)

    base.merge(meetings: my_meetings(from..to, person), tasks: my_tasks(from.to_date, to, person),
               overdue_note: 'tasks incluye las atrasadas (vencimiento antes de hoy).')
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

  # Solo las que siguen agendadas (las realizadas o «no asistió» ya no son pendientes del día).
  def my_meetings(range, person = @user)
    @account.case_meetings.where(organizer_id: person.id, starts_at: range, status: :scheduled)
            .order(:starts_at).limit(30).map { |m| meeting_ref(m) }
  end

  # Vencen hasta `until_time` o se pasaron a un día del rango; las pasadas a un día fuera
  # del rango (antes o después) no salen.
  def my_tasks(first_day, until_time, person = @user)
    last_day = until_time.to_date
    scope = @account.case_tasks.pending.where(assignee_id: person.id)
    scope.where(planned_on: first_day..last_day)
         .or(scope.where(planned_on: nil, due_at: ..until_time))
         .or(scope.where(planned_on: ...first_day, due_at: ..until_time))
         .order(:due_at).limit(30).map { |t| task_ref(t) }
  end

  private

  def agenda_range(args)
    from = @zone.parse(args['from'].to_s)&.beginning_of_day || @zone.now.beginning_of_day
    [from, @zone.parse(args['to'].to_s)&.end_of_day || from.end_of_day]
  end

  # Un solo día que la página Mi día sabe mostrar (Cases::MyDayPlan.day_from acepta ±1 de hoy).
  def page_day?(from, to)
    day = from.to_date
    day == to.to_date && (day - @zone.today).abs <= 1
  end

  # Lo mismo que la página Mi día (y la tarjeta del Resumen), con la misma consulta.
  def my_day_like_page(day, person)
    params = { mode: 'my_day', assignee_id: person.id.to_s, day: day.iso8601, tz: @zone.tzinfo.name }
    result = Cases::TasksInboxQuery.new(account: @account, current_user: @user, params: params.with_indifferent_access).call
    tasks = result[:rows].map(&:first)
    planned = result[:planned_ids]
    shown = tasks.first(DAY_LIMIT).map { |t| task_ref(t).merge(planned.include?(t.id) ? { in_my_order: true } : {}) }
    { meetings: result[:agenda].map { |m| meeting_ref(m) }, tasks: shown, more_tasks: result[:total] - shown.size,
      later_count: result[:later_count],
      note: 'Igual que la página Mi día: tasks en su orden (primero «Mi orden de hoy», luego por prioridad). ' \
            'Si more_tasks > 0 di cuántas más hay en Mi día; later_count son las pasadas a otro día.' }
  end

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
