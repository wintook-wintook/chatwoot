# frozen_string_literal: true

# Tareas que se repiten — las fechas: la primera, la que sigue a una fecha (fecha fija) y la que sigue a la última
# vez que la hizo ('after_done').
#   cada N días · cada N semanas (opcional: en ciertos días, 0 = domingo … 6 = sábado) · cada N meses (mismo día;
#   si el mes es más corto, su último día).
class TaskRecurrences::Cadence
  SEARCH_DAYS = 800

  def initialize(recurrence)
    @rec = recurrence
    @start = recurrence.starts_on
  end

  # La primera vez: el día que empieza o, con días de la semana, el primero de ellos desde ahí.
  def first_on
    return @start unless weekly_days?

    (@start..(@start + SEARCH_DAYS)).find { |day| weekly_match?(day) }
  end

  # Fecha fija: la siguiente después de `date`.
  def next_after(date)
    case @rec.unit
    when 'day' then date + @rec.every
    when 'month' then month_after(date)
    else weekly_days? ? ((date + 1)..(date + SEARCH_DAYS)).find { |day| weekly_match?(day) } : date + (7 * @rec.every)
    end
  end

  # 'after_done': el intervalo contado desde el día que la hizo.
  def after(date)
    case @rec.unit
    when 'day' then date + @rec.every
    when 'month' then date >> @rec.every
    else date + (7 * @rec.every)
    end
  end

  private

  def weekly_days?
    @rec.unit == 'week' && Array(@rec.weekdays).any?
  end

  # En los días elegidos, y cada N semanas contadas desde la semana en que empieza.
  def weekly_match?(day)
    return false unless @rec.weekdays.include?(day.wday)

    weeks = (day.beginning_of_week(:sunday) - @start.beginning_of_week(:sunday)).to_i / 7
    (weeks % @rec.every).zero?
  end

  def month_after(date)
    months = ((date.year * 12) + date.month) - ((@start.year * 12) + @start.month)
    target = @start >> (((months / @rec.every) + 1) * @rec.every)
    target <= date ? target >> @rec.every : target
  end
end
