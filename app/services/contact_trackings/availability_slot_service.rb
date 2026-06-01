# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar

module ContactTrackings
  class AvailabilitySlotService
    WORK_HOUR_START = 9
    WORK_HOUR_END   = 18
    SLOT_DURATION   = 60  # minutos
    DAYS_AHEAD      = 5   # días hábiles a consultar
    MAX_SLOTS       = 5   # máximo de slots a retornar

    def initialize(calendar_integration_ids:, timezone: 'America/Mexico_City')
      @calendar_integration_ids = Array(calendar_integration_ids).map(&:to_i).uniq
      @timezone = timezone.presence || 'America/Mexico_City'
    end

    def call
      return [] if @calendar_integration_ids.empty?

      integrations = UserCalendarIntegration.where(id: @calendar_integration_ids)
      return [] if integrations.empty?

      time_min = align_to_slot(Time.current + 1.hour)
      time_max = business_days_from_now(DAYS_AHEAD)

      all_slots = []

      integrations.each do |integration|
        busy_periods = fetch_busy_periods(integration, time_min, time_max)
        slots = free_slots_for(integration, busy_periods, time_min, time_max)
        all_slots.concat(slots)
      rescue StandardError => e
        Rails.logger.warn "[AvailabilitySlotService] ⚠️ Error en integración ##{integration.id}: #{e.message}"
      end

      all_slots.sort_by { |s| s[:slot] }.first(MAX_SLOTS)
    end

    private

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
        slot_end = current + SLOT_DURATION.minutes

        if within_work_hours?(current, slot_end) && !overlaps_busy?(current, slot_end, busy_periods)
          slots << {
            slot:                    current,
            end_time:                slot_end,
            agent_name:              agent_name,
            calendar_integration_id: integration.id
          }
          break if slots.size >= MAX_SLOTS
        end

        current += SLOT_DURATION.minutes
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
      remainder = time.min % SLOT_DURATION
      return time.change(sec: 0) if remainder.zero?

      (time + (SLOT_DURATION - remainder).minutes).change(sec: 0)
    end

    def business_days_from_now(days)
      date  = Time.current
      count = 0
      while count < days
        date  += 1.day
        count += 1 unless date.saturday? || date.sunday?
      end
      date.end_of_day
    end
  end
end
