# frozen_string_literal: true

# ================================================================================
# prospeccion P2 — SUMAR HORAS HÁBILES (§10.9)
# ================================================================================
#   bandeja con horario de atención → solo cuentan las horas abiertas de cada día
#   bandeja sin horario             → cuentan las 24 h de lunes a viernes; sábado y
#                                     domingo no (feedback: nunca en fin de semana)
#
# Se calcula en la zona horaria de la bandeja. Si en DAYS_AHEAD días no hay ninguna hora
# abierta (horario cerrado toda la semana), cae al cálculo sin horario.
# ================================================================================
class TrackingCampaigns::BusinessClock
  DAYS_AHEAD = 60

  def initialize(inbox)
    @inbox = inbox
    @zone = inbox&.timezone.presence || 'UTC'
  end

  def add(from, hours)
    return nil if hours.blank?

    local = from.in_time_zone(@zone)
    (working_hours? && within_hours(local, hours.to_i * 60)) || within_weekdays(local, hours.to_i * 60)
  end

  private

  def working_hours?
    @inbox&.working_hours_enabled? && @inbox.working_hours.any?
  end

  def within_hours(local, minutes)
    hours = @inbox.working_hours.index_by(&:day_of_week)
    left = minutes
    DAYS_AHEAD.times do |offset|
      day = local.to_date + offset
      opens, closes = window(hours[day.wday], day)
      next if opens.nil?

      start = [opens, local].max
      next if start >= closes

      available = ((closes - start) / 60).floor
      return start + left.minutes if left <= available

      left -= available
    end
    nil
  end

  def window(hour, day)
    return nil if hour.nil? || hour.closed_all_day?

    midnight = ActiveSupport::TimeZone[@zone].local(day.year, day.month, day.day)
    return [midnight, midnight + 1.day] if hour.open_all_day?

    [midnight.change(hour: hour.open_hour.to_i, min: hour.open_minutes.to_i),
     midnight.change(hour: hour.close_hour.to_i, min: hour.close_minutes.to_i)]
  end

  def within_weekdays(local, minutes)
    time = local
    left = minutes
    while left.positive?
      time = time.next_day.beginning_of_day while weekend?(time)
      until_midnight = ((time.end_of_day + 1.second - time) / 60).floor
      return time + left.minutes if left <= until_midnight

      left -= until_midnight
      time = time.end_of_day + 1.second
    end
    time += 1.day while weekend?(time)
    time
  end

  def weekend?(time)
    time.saturday? || time.sunday?
  end
end
