# frozen_string_literal: true

# @tickets_cases 2I — Reloj de SLA con horario laboral y pausa.
#
# Calcula los minutos transcurridos de un ticket descontando:
#   1. el tiempo pausado en estados de espera (sla_paused_minutes + pausa en curso), y
#   2. (si la política es business_hours_only) las horas fuera del horario laboral
#      configurado en account.working_hours (modelo nativo WorkingHour, día 0-6).
#
# Las horas se interpretan en la zona horaria de la aplicación (Time.zone).
class Cases::SlaClockService
  class << self
    # Minutos efectivos transcurridos para evaluar el SLA del ticket.
    def elapsed_minutes(ticket, policy, now: Time.current)
      business = policy&.business_hours_only
      total    = duration(ticket.account, ticket.created_at, now, business)
      paused   = ticket.sla_paused_minutes
      paused  += duration(ticket.account, ticket.sla_paused_since, now, business) if ticket.sla_paused_since.present?
      [total - paused, 0].max
    end

    # Minutos entre dos instantes (hábiles si business: true).
    def minutes_between(ticket, from, to, business: false)
      duration(ticket.account, from, to, business)
    end

    # Minutos hábiles entre dos instantes según account.working_hours.
    # Si la cuenta no tiene horario configurado, cae a minutos lineales.
    def business_minutes(account, from, to)
      from = from.in_time_zone
      to   = to.in_time_zone
      return 0 if to <= from

      schedule = account.working_hours.index_by(&:day_of_week)
      return wall_minutes(from, to) if schedule.blank?

      total  = 0.0
      cursor = from
      while cursor < to
        seg_end = [cursor.end_of_day, to].min
        wh      = schedule[cursor.wday]
        total  += day_minutes(wh, cursor, seg_end) if wh
        cursor  = (cursor + 1.day).beginning_of_day
      end
      total.round
    end

    private

    def duration(account, from, to, business)
      return 0 if from.blank? || to.blank?

      business ? business_minutes(account, from, to) : wall_minutes(from, to)
    end

    def wall_minutes(from, to)
      [((to - from) / 60).round, 0].max
    end

    # Minutos del segmento [seg_start, seg_end] (mismo día) dentro del horario laboral.
    def day_minutes(working_hour, seg_start, seg_end)
      return 0 if working_hour.closed_all_day
      return wall_minutes(seg_start, seg_end) if working_hour.open_all_day

      open_at  = seg_start.change(hour: working_hour.open_hour,  min: working_hour.open_minutes,  sec: 0)
      close_at = seg_start.change(hour: working_hour.close_hour, min: working_hour.close_minutes, sec: 0)

      lo = [seg_start, open_at].max
      hi = [seg_end, close_at].min
      return 0 if hi <= lo

      (hi - lo) / 60.0
    end
  end
end
