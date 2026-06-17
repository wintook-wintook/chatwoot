# frozen_string_literal: true

require 'rails_helper'

# proyecto@bot_seguimiento_calendar
RSpec.describe ContactTrackings::AvailabilitySlotService do
  subject(:service) { described_class.new(calendar_integration_ids: [1, 2]) }

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
