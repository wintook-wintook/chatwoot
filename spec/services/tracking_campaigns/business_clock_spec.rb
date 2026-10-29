# frozen_string_literal: true

require 'rails_helper'

# prospeccion P2 (docs/prospeccion_estudio.md §10.9) — sumar horas hábiles.
RSpec.describe TrackingCampaigns::BusinessClock do
  let(:zone) { ActiveSupport::TimeZone['America/Mexico_City'] }
  # Lun–vie 9:00–17:00 (el horario que Chatwoot crea por omisión)
  let(:inbox) { create(:inbox, timezone: 'America/Mexico_City', working_hours_enabled: true) }
  let(:no_hours) { create(:inbox, timezone: 'America/Mexico_City', working_hours_enabled: false) }

  it 'sin horas no hay vencimiento' do
    expect(described_class.new(inbox).add(Time.current, nil)).to be_nil
  end

  describe 'con horario de atención' do
    it 'cuenta solo las horas abiertas: lunes 15:00 + 4 h → martes 11:00' do
      expect(described_class.new(inbox).add(zone.local(2026, 10, 5, 15), 4)).to eq(zone.local(2026, 10, 6, 11))
    end

    it 'fuera de horario empieza en la siguiente apertura: lunes 20:00 + 2 h → martes 11:00' do
      expect(described_class.new(inbox).add(zone.local(2026, 10, 5, 20), 2)).to eq(zone.local(2026, 10, 6, 11))
    end

    it 'el fin de semana no cuenta: viernes 16:00 + 4 h → lunes 12:00' do
      expect(described_class.new(inbox).add(zone.local(2026, 10, 9, 16), 4)).to eq(zone.local(2026, 10, 12, 12))
    end
  end

  describe 'sin horario' do
    it 'cuenta las 24 h de lunes a viernes: viernes 20:00 + 8 h → lunes 04:00' do
      expect(described_class.new(no_hours).add(zone.local(2026, 10, 9, 20), 8)).to eq(zone.local(2026, 10, 12, 4))
    end

    it 'entregado en sábado: empieza a contar el lunes' do
      expect(described_class.new(no_hours).add(zone.local(2026, 10, 10, 12), 4)).to eq(zone.local(2026, 10, 12, 4))
    end
  end
end
