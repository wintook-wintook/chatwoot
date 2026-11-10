# Periodos con nombre para las consultas de ventas (Dali): rango en la zona del usuario,
# su etiqueta y qué tanto ya pasó (el ritmo esperado).
module Sales::Period
  NAMES = %w[this_month last_month this_quarter last_quarter this_year last_year].freeze

  module_function

  def range(period, zone:, from: nil, to: nil)
    return day(from, zone).beginning_of_day..day(to, zone).end_of_day if from.present? && to.present?

    first, last = bounds(period.to_s, Time.current.in_time_zone(zone).to_date)
    first.in_time_zone(zone).beginning_of_day..last.in_time_zone(zone).end_of_day
  end

  def bounds(period, today)
    case period
    when 'last_month' then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
    when 'this_quarter' then [today.beginning_of_quarter, today.end_of_quarter]
    when 'last_quarter' then [(today - 3.months).beginning_of_quarter, (today - 3.months).end_of_quarter]
    when 'this_year' then [today.beginning_of_year, today.end_of_year]
    when 'last_year' then [today.prev_year.beginning_of_year, today.prev_year.end_of_year]
    else [today.beginning_of_month, today.end_of_month]
    end
  end

  def day(value, zone)
    Date.parse(value.to_s).in_time_zone(zone)
  rescue ArgumentError
    raise ArgumentError, 'Fecha inválida; usa YYYY-MM-DD.'
  end

  def label(range)
    { from: range.begin.to_date.iso8601, to: range.end.to_date.iso8601 }
  end

  def previous(range, compare)
    return (range.begin - 1.year)..(range.end - 1.year) if compare.to_s == 'last_year'

    length = range.end - range.begin
    (range.begin - length - 1.second)..(range.begin - 1.second)
  end

  # Qué porcentaje del periodo ya pasó (0 si no empieza, 100 si ya terminó).
  def elapsed_percent(range)
    now = Time.current.clamp(range.begin, range.end)
    ((now - range.begin) / (range.end - range.begin) * 100).clamp(0, 100).round(1)
  end
end
