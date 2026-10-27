# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — CUÁNDO LE ESCRIBE EL AGENTE A UN INSCRITO
# ================================================================================
# Plan: docs/automatizacion_campanas_plan.md (§3.3).
#
#   hora de la inscripción
#     + espera de la campaña (entry_delay_minutes)
#     no antes del INICIO de la ventana (scheduled_for)
#     dentro del HORARIO DE ATENCIÓN del inbox, si la campaña lo pide y el inbox lo
#       tiene activado: fuera de horario → la siguiente apertura
#     ¿después del FIN (ends_at)?  → nil: fuera de la ventana
#
# El horario se lee en la zona horaria del inbox, que es la del negocio.
# ================================================================================
class TrackingCampaigns::Schedule
  # Una semana alcanza para encontrar la siguiente apertura; si no la hay, el inbox está
  # cerrado todos los días y no hay a qué hora escribir.
  DAYS_AHEAD = 8

  def initialize(campaign, inbox = campaign.inbox)
    @campaign = campaign
    @inbox = inbox
  end

  # La hora a la que se programa el seguimiento, o nil si cae fuera de la ventana.
  # day_offset (prospeccion V3): días hábiles de más, para repartir un lote con tope diario.
  def send_at(entered_at = Time.current, day_offset: 0)
    time = [entered_at + @campaign.entry_delay_minutes.to_i.minutes, @campaign.scheduled_for].compact.max
    time = business_days_later(time, day_offset) if day_offset.positive?
    time = open_time(time)
    return nil if time.nil? || (@campaign.ends_at && time > @campaign.ends_at)

    time
  end

  private

  # Dentro del horario de la bandeja; sin horario, Prospección al menos nunca en fin de semana.
  def open_time(time)
    return next_open(time) if working_hours?

    @campaign.prospecting? ? next_weekday(time) : time
  end

  # Prospección: sin horario en la bandeja, al menos nunca sábado ni domingo (misma hora, el lunes).
  def next_weekday(time)
    local = time.in_time_zone(zone)
    local += 1.day while local.saturday? || local.sunday?
    local
  end

  # Al inicio de cada día hábil de más (a la hora de apertura si hay horario; si no, a la misma hora).
  def business_days_later(time, days)
    local = time.in_time_zone(zone)
    count = 0
    while count < days
      local += 1.day
      count += 1 unless local.saturday? || local.sunday?
    end
    working_hours? ? local.beginning_of_day : local
  end

  def zone
    @inbox&.timezone.presence || 'UTC'
  end

  def working_hours?
    @campaign.respect_working_hours && @inbox&.working_hours_enabled?
  end

  def next_open(time)
    local = time.in_time_zone(@inbox.timezone.presence || 'UTC')
    hours = @inbox.working_hours.index_by(&:day_of_week)

    DAYS_AHEAD.times do |offset|
      day = local.to_date + offset
      slot = open_slot(hours[day.wday], day, local)
      return slot if slot
    end
    nil
  end

  # La primera hora abierta de ese día a partir de `from`, o nil si ese día ya no abre.
  def open_slot(hour, day, from)
    return nil if hour.nil? || hour.closed_all_day?

    midnight = from.time_zone.local(day.year, day.month, day.day)
    opens = midnight.change(hour: hour.open_hour.to_i, min: hour.open_minutes.to_i)
    closes = hour.open_all_day? ? midnight.end_of_day : midnight.change(hour: hour.close_hour.to_i, min: hour.close_minutes.to_i)

    start = [opens, from].max
    start < closes ? start : nil
  end
end
