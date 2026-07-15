# frozen_string_literal: true

require 'rails_helper'

# proyecto@bot_seguimiento_calendar
RSpec.describe ContactTrackings::AvailabilitySlotService do
  subject(:service) { described_class.new(calendar_integration_ids: [1, 2]) }

  describe '#within_work_hours? con working_hours del inbox (Opción A)' do
    def wh(day, open_h = nil, close_h = nil, closed: false)
      instance_double(WorkingHour, day_of_week: day, closed_all_day?: closed,
                                   open_hour: open_h, open_minutes: 0, close_hour: close_h, close_minutes: 0)
    end

    let(:tz) { 'America/Mexico_City' }
    # lunes 09–13; martes y domingo cerrados
    let(:working_hours) { [wh(1, 9, 13), wh(2, closed: true), wh(0, closed: true)] }

    subject(:service) do
      described_class.new(calendar_integration_ids: [1], timezone: tz, working_hours: working_hours)
    end

    it 'acepta un slot dentro de la ventana del lunes' do
      start = Time.find_zone(tz).local(2026, 6, 15, 9, 0) # lunes 09:00
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(true)
    end

    it 'rechaza un slot que termina pasado el cierre (12:45–13:15 > 13:00)' do
      start = Time.find_zone(tz).local(2026, 6, 15, 12, 45)
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(false)
    end

    it 'rechaza un día cerrado (martes)' do
      start = Time.find_zone(tz).local(2026, 6, 16, 10, 0) # martes
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(false)
    end
  end

  describe '#within_work_hours? sin working_hours (default 9–18 lun–vie)' do
    let(:tz) { 'America/Mexico_City' }
    subject(:service) { described_class.new(calendar_integration_ids: [1], timezone: tz) }

    it 'acepta lunes 10:00' do
      start = Time.find_zone(tz).local(2026, 6, 15, 10, 0)
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(true)
    end

    it 'rechaza sábado' do
      start = Time.find_zone(tz).local(2026, 6, 20, 10, 0) # sábado
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(false)
    end

    it 'rechaza fuera del horario (18:00)' do
      start = Time.find_zone(tz).local(2026, 6, 15, 18, 0)
      expect(service.send(:within_work_hours?, start, start + 30.minutes)).to be(false)
    end
  end

  describe '#balance_slots (reparto entre agentes)' do
    def slot(time, agent_id)
      { slot: time, end_time: time + 30.minutes, agent_name: "Agente #{agent_id}", calendar_integration_id: agent_id }
    end

    it 'no ofrece el mismo horario dos veces y reparte entre los dos agentes' do
      times = (1..6).map { |i| Time.current.change(hour: 9, min: 0) + (i * 30).minutes }
      slots_by_agent = {
        1 => times.map { |t| slot(t, 1) },
        2 => times.map { |t| slot(t, 2) }
      }

      result = service.send(:balance_slots, slots_by_agent)

      expect(result.size).to eq(5)
      expect(result.map { |s| s[:slot] }.uniq.size).to eq(5) # sin horarios repetidos
      counts = result.group_by { |s| s[:calendar_integration_id] }.transform_values(&:size)
      expect(counts.keys).to contain_exactly(1, 2)            # aparecen ambos agentes
      expect(counts.values.max).to be <= 3                    # ninguno acapara (≈ 3/2)
    end

    it 'usa los horarios de un agente cuando el otro no tiene disponibilidad temprana' do
      morning = [Time.current.change(hour: 9, min: 0), Time.current.change(hour: 9, min: 30)]
      afternoon = [Time.current.change(hour: 15, min: 0)]

      result = service.send(:balance_slots, {
                              1 => morning.map { |t| slot(t, 1) },
                              2 => afternoon.map { |t| slot(t, 2) }
                            })

      expect(result.size).to eq(3)
      expect(result.map { |s| s[:slot] }).to eq([morning[0], morning[1], afternoon[0]]) # orden cronológico
    end
  end
end
