# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F1 (docs/automatizacion_campanas_plan.md §3.3)
RSpec.describe TrackingCampaigns::Schedule do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City', working_hours_enabled: true) }
  let(:zone) { ActiveSupport::TimeZone['America/Mexico_City'] }
  # Lunes a viernes 9:00–17:00, sábado y domingo cerrado (el horario por defecto de Chatwoot).
  let(:monday_noon) { zone.local(2026, 10, 5, 12, 0) }
  let(:campaign) { build(:tracking_campaign, account: account, inbox: inbox, scheduled_for: monday_noon - 1.day) }

  def send_at(entered_at)
    described_class.new(campaign).send_at(entered_at)
  end

  it 'dentro del horario y de la ventana: a la hora de la inscripción' do
    expect(send_at(monday_noon)).to eq(monday_noon)
  end

  it 'suma la espera de la campaña' do
    campaign.entry_delay_minutes = 90

    expect(send_at(monday_noon)).to eq(monday_noon + 90.minutes)
  end

  it 'nunca antes del inicio de la ventana' do
    campaign.scheduled_for = monday_noon + 2.hours

    expect(send_at(monday_noon)).to eq(monday_noon + 2.hours)
  end

  it 'fuera de horario pasa a la siguiente apertura, saltando el fin de semana' do
    friday_night = zone.local(2026, 10, 9, 20, 0)

    expect(send_at(zone.local(2026, 10, 5, 7, 30))).to eq(zone.local(2026, 10, 5, 9, 0))
    expect(send_at(friday_night)).to eq(zone.local(2026, 10, 12, 9, 0))
  end

  it 'sin horario: el inbox sin horario activado o la campaña que no lo pide escriben a cualquier hora' do
    saturday = zone.local(2026, 10, 10, 22, 0)

    inbox.update!(working_hours_enabled: false)
    expect(send_at(saturday)).to eq(saturday)

    inbox.update!(working_hours_enabled: true)
    campaign.respect_working_hours = false
    expect(send_at(saturday)).to eq(saturday)
  end

  it 'lo que cae después del fin queda fuera de la ventana' do
    campaign.ends_at = zone.local(2026, 10, 9, 18, 0)

    expect(send_at(zone.local(2026, 10, 9, 16, 0))).to eq(zone.local(2026, 10, 9, 16, 0))
    # viernes 20:00 → la apertura es el lunes, después del fin
    expect(send_at(zone.local(2026, 10, 9, 20, 0))).to be_nil
  end

  it 'un día abierto todo el día acepta cualquier hora' do
    inbox.working_hours.find_by(day_of_week: 6).update!(closed_all_day: false, open_all_day: true)
    saturday = zone.local(2026, 10, 10, 23, 0)

    expect(send_at(saturday)).to eq(saturday)
  end
end
