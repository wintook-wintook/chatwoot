# frozen_string_literal: true

# Tareas que se repiten — fija la próxima fecha al darla de alta o al cambiarle cuándo se repite, y crea la de hoy
# si ya toca (TaskRecurrences::Generator).
module TaskRecurrences::Schedule
  module_function

  CADENCE_FIELDS = %w[mode every unit weekdays starts_on at_time time_zone].freeze

  def start!(recurrence)
    recurrence.time_zone = recurrence.time_zone.presence || Time.zone.name
    recurrence.next_on = first_from_today(recurrence)
    recurrence.save!
    TaskRecurrences::Generator.new(recurrence).call
  end

  # Cambiar campos; si cambió cuándo se repite (o se reanuda), recalcula la próxima fecha.
  def change!(recurrence, attrs)
    recurrence.assign_attributes(attrs)
    reschedule = recurrence.changed.intersect?(CADENCE_FIELDS) || (recurrence.status_changed? && recurrence.status == 'active')
    recurrence.next_on = first_from_today(recurrence) if reschedule && recurrence.valid?
    recurrence.save!
    TaskRecurrences::Generator.new(recurrence).call if reschedule
  end

  # La primera fecha desde hoy (o desde que empieza, si es después). En 'after_done' con una vez pendiente
  # espera a que la haga.
  def first_from_today(recurrence)
    return nil unless recurrence.valid?
    return after_done_from_today(recurrence) if !recurrence.fixed? && recurrence.persisted?

    fixed_from_today(recurrence)
  end

  def fixed_from_today(recurrence)
    date = recurrence.cadence.first_on
    date = recurrence.cadence.next_after(date) while date && date < recurrence.today
    date
  end

  # 'after_done' ya en marcha: si hay una pendiente, espera; si ya la hizo, el intervalo desde esa vez.
  def after_done_from_today(recurrence)
    return nil if recurrence.pending_item

    last = recurrence.last_done_on
    return [recurrence.cadence.after(last), recurrence.today].max if last

    [recurrence.cadence.first_on, recurrence.today].compact.max
  end
end
