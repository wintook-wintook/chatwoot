# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F3 (docs/automatizacion_campanas_plan.md §6)
RSpec.describe TrackingCampaigns::WindowJob do
  let(:account) { create(:account) }

  def campaign(status, starts:, ends: nil)
    create(:tracking_campaign, account: account, status: status, scheduled_for: starts, ends_at: ends)
  end

  it 'abre las programadas cuyo inicio llegó y cierra las que pasaron su fin' do
    due = campaign('draft', starts: 1.minute.ago)
    future = campaign('draft', starts: 1.hour.from_now)
    over = campaign('running', starts: 2.days.ago, ends: 1.minute.ago)
    paused_over = campaign('paused', starts: 2.days.ago, ends: 1.minute.ago)
    open_ended = campaign('running', starts: 2.days.ago)

    described_class.perform_now

    expect(due.reload.status).to eq('running')
    expect(future.reload.status).to eq('draft')
    expect(over.reload.status).to eq('finished')
    expect(paused_over.reload.status).to eq('finished')
    expect(open_ended.reload.status).to eq('running')
  end

  it 'una programada cuyo fin ya pasó queda finalizada, no en curso' do
    late = campaign('draft', starts: 2.days.ago, ends: 1.day.ago)

    described_class.perform_now
    expect(late.reload.status).to eq('finished')
  end

  it 'cerrar la campaña no toca los seguimientos de los inscritos' do
    over = campaign('running', starts: 2.days.ago, ends: 1.minute.ago)
    tracking = create(:contact_tracking, account: account, tracking_campaign: over, status: 'active')

    described_class.perform_now
    expect(tracking.reload.status).to eq('active')
  end

  it 'está programado en config/schedule.yml' do
    schedule = YAML.load_file(Rails.root.join('config/schedule.yml'))

    expect(schedule['tracking_campaigns_window']).to include('class' => 'TrackingCampaigns::WindowJob', 'cron' => '*/5 * * * *')
  end
end
