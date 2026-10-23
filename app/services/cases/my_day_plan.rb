# frozen_string_literal: true

# @tickets_cases — Plan-Bandeja-Prioridad F2: el orden propio de «Mi día».
#
#   Cases::MyDayPlan.new(account:, user:, day: '2026-10-21').save!([12, 7, 30])
#
# Guarda por REEMPLAZO: la lista recibida es el plan completo del día, en orden.
# Las tareas del agente que estaban en el plan de ese día y ya no vienen salen de
# él; las que entran por primera vez marcan `focused_at`. Solo cuentan tareas
# PENDIENTES asignadas al agente: un id ajeno o ya hecho se ignora.
#
# El día lo manda el navegador (fecha LOCAL del agente): el servidor corre en UTC
# y en México «mañana» llegaría a las 6 de la tarde. Se acepta hoy ±1 día del
# servidor; cualquier otra cosa cae a hoy.
class Cases::MyDayPlan
  def self.day_from(raw)
    day = Date.iso8601(raw.to_s)
    (day - Time.zone.today).abs <= 1 ? day : Time.zone.today
  rescue ArgumentError
    Time.zone.today
  end

  attr_reader :day

  def initialize(account:, user:, day:)
    @account = account
    @user = user
    @day = self.class.day_from(day)
  end

  def tasks
    CaseTask.where(account_id: @account.id, assignee_id: @user.id)
  end

  def save!(task_ids)
    ids = Array(task_ids).map(&:to_i).uniq
    allowed = tasks.pending.where(id: ids).index_by(&:id)
    ordered = ids.filter_map { |id| allowed[id] }

    CaseTask.transaction do
      tasks.where(planned_on: day).where.not(id: ordered.map(&:id))
           .update_all(planned_on: nil, focus_position: nil, focused_at: nil) # rubocop:disable Rails/SkipsModelValidations
      ordered.each_with_index { |task, position| place(task, position) }
    end
    ordered.map(&:id)
  end

  private

  def place(task, position)
    attrs = { planned_on: day, focus_position: position }
    attrs[:focused_at] = Time.current unless task.planned_on == day && task.focused_at
    task.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
  end
end
