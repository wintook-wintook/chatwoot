# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar

module ContactTrackings
  class AvailabilitySlotService
    WORK_HOUR_START    = 9
    WORK_HOUR_END      = 18
    DEFAULT_DURATION   = 30  # minutos
    DAYS_AHEAD         = 5   # días hábiles a consultar
    MAX_SLOTS          = 5   # máximo de slots a retornar

    def initialize(calendar_integration_ids:, timezone: 'America/Mexico_City', slot_duration: DEFAULT_DURATION)
      @calendar_integration_ids = Array(calendar_integration_ids).map(&:to_i).uniq
      @timezone      = timezone.presence || 'America/Mexico_City'
      @slot_duration = slot_duration.to_i.positive? ? slot_duration.to_i : DEFAULT_DURATION
    end

    # `from:` permite anclar la búsqueda cerca de un día/hora pedido por el cliente
    # (negociación multi-turno); por defecto busca desde "ahora + 1h".
    def call(from: nil)
      return [] if @calendar_integration_ids.empty?

      integrations = UserCalendarIntegration.where(id: @calendar_integration_ids)
      return [] if integrations.empty?

      start_at = [Time.current + 1.hour, from].compact.max
      time_min = align_to_slot(start_at)
      time_max = business_days_from_now(start_at, DAYS_AHEAD)

      slots_by_agent = {}

      integrations.each do |integration|
        busy_periods = fetch_busy_periods(integration, time_min, time_max)
        slots_by_agent[integration.id] = free_slots_for(integration, busy_periods, time_min, time_max)
      rescue StandardError => e
        Rails.logger.warn "[AvailabilitySlotService] ⚠️ Error en integración ##{integration.id}: #{e.message}"
      end

      balance_slots(slots_by_agent)
    end

    # Verifica si un horario EXACTO propuesto por el cliente está libre (dentro del
    # horario laboral y sin choque) en alguna de las agendas. Devuelve el slot con la
    # agenda que lo tiene libre, o nil. Usado por la negociación multi-turno.
    def slot_for(requested_start)
      return nil if requested_start.blank? || @calendar_integration_ids.empty?

      aligned  = align_to_slot(requested_start)
      slot_end = aligned + @slot_duration.minutes
      return nil if aligned < Time.current
      return nil unless within_work_hours?(aligned, slot_end)

      UserCalendarIntegration.where(id: @calendar_integration_ids).each do |integration|
        busy = fetch_busy_periods(integration, aligned - 1.hour, slot_end + 1.hour)
        next if overlaps_busy?(aligned, slot_end, busy)

        return {
          slot:                    aligned,
          end_time:                slot_end,
          agent_name:              integration.user&.name || 'Agente',
          calendar_integration_id: integration.id
        }
      end
      nil
    rescue StandardError => e
      Rails.logger.warn "[AvailabilitySlotService] ⚠️ slot_for falló: #{e.message}"
      nil
    end

    private

    # Reparte los horarios ofrecidos entre los agentes para (a) no ofrecer el mismo
    # horario dos veces y (b) no sobrecargar a un solo agente: agrupa por horario y,
    # en cada uno, elige al agente con MENOS citas asignadas hasta ahora (desempate
    # estable por id). Devuelve los MAX_SLOTS horarios distintos más tempranos.
    def balance_slots(slots_by_agent)
      by_time = Hash.new { |h, k| h[k] = [] }
      slots_by_agent.each_value do |slots|
        slots.each { |s| by_time[s[:slot]] << s }
      end

      load = Hash.new(0)
      by_time.keys.sort.first(MAX_SLOTS).map do |time|
        chosen = by_time[time].min_by { |s| [load[s[:calendar_integration_id]], s[:calendar_integration_id]] }
        load[chosen[:calendar_integration_id]] += 1
        chosen
      end
    end

    def fetch_busy_periods(integration, time_min, time_max)
      calendar_ids = integration.enabled_calendar_ids.presence || ['primary']
      service  = GoogleCalendarService.new(integration)
      response = service.free_busy(calendars: calendar_ids, time_min: time_min, time_max: time_max)

      (response['calendars'] || {}).flat_map do |_cal_id, cal_data|
        (cal_data['busy'] || []).map do |busy|
          { start: Time.parse(busy['start']), end: Time.parse(busy['end']) }
        end
      end
    rescue StandardError => e
      Rails.logger.warn "[AvailabilitySlotService] ⚠️ free_busy falló para integración ##{integration.id}: #{e.message}"
      []
    end

    def free_slots_for(integration, busy_periods, time_min, time_max)
      agent_name = integration.user&.name || 'Agente'
      slots      = []
      current    = time_min

      while current < time_max
        slot_end = current + @slot_duration.minutes

        if within_work_hours?(current, slot_end) && !overlaps_busy?(current, slot_end, busy_periods)
          slots << {
            slot:                    current,
            end_time:                slot_end,
            agent_name:              agent_name,
            calendar_integration_id: integration.id
          }
          break if slots.size >= MAX_SLOTS
        end

        current += @slot_duration.minutes
      end

      slots
    end

    def within_work_hours?(slot_start, slot_end)
      local_start = slot_start.in_time_zone(@timezone)
      local_end   = slot_end.in_time_zone(@timezone)

      return false if local_start.saturday? || local_start.sunday?

      local_start.hour >= WORK_HOUR_START &&
        local_start.hour < WORK_HOUR_END &&
        (local_end.hour < WORK_HOUR_END || (local_end.hour == WORK_HOUR_END && local_end.min == 0))
    end

    def overlaps_busy?(slot_start, slot_end, busy_periods)
      busy_periods.any? { |b| slot_start < b[:end] && slot_end > b[:start] }
    end

    def align_to_slot(time)
      remainder = time.min % @slot_duration
      return time.change(sec: 0) if remainder.zero?

      (time + (@slot_duration - remainder).minutes).change(sec: 0)
    end

    def business_days_from_now(start_time, days)
      date  = start_time
      count = 0
      while count < days
        date  += 1.day
        count += 1 unless date.saturday? || date.sunday?
      end
      date.end_of_day
    end
  end
end
