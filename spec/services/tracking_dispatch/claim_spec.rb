# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 2: una vuelta del despachador
RSpec.describe TrackingDispatch::Claim do
  let(:account) { create(:account) }
  let(:inbox_a) { create(:inbox, account: account) }
  let(:inbox_b) { create(:inbox, account: account) }
  let(:env) { { 'TRACKING_DISPATCHER_ACCOUNTS' => account.id.to_s, 'TRACKING_DISPATCH_PER_INBOX_PER_ROUND' => '2' } }

  def due(inbox, minutes_ago: 1, **attributes)
    create(:contact_tracking, account: account, inbox: inbox, contact: create(:contact, account: account), **attributes)
      .tap { |t| t.update_columns(scheduled_for: minutes_ago.minutes.ago) } # rubocop:disable Rails/SkipsModelValidations
  end

  def claim
    with_modified_env(env) { described_class.new.call }
  end

  before { allow(TrackingDispatch::MessagingTier).to receive(:daily_limit).and_return(nil) }

  it 'marca los vencidos como activos con la marca de la vuelta' do
    tracking = due(inbox_a)
    due(inbox_a, minutes_ago: -10) # todavía no le toca

    result = claim

    expect(result.map(&:first)).to eq([tracking.id])
    expect(tracking.reload).to have_attributes(status: 'active')
    expect(TrackingDispatch.token(tracking.dispatched_at)).to eq(result.first.last)
  end

  it 'reparte por turnos: cada inbox aporta hasta su tope por vuelta' do
    a = Array.new(4) { |i| due(inbox_a, minutes_ago: 10 - i) }
    b = due(inbox_b)

    ids = claim.map(&:first)

    expect(ids).to contain_exactly(a[0].id, a[1].id, b.id)
  end

  it 'respeta lo que le queda al número en el minuto' do
    3.times { due(inbox_a) }
    Redis::Alfred.set("tracking_dispatch:minute:#{inbox_a.id}:#{Time.current.to_i / 60}", 599, ex: 120)

    expect(claim.size).to eq(1)
  end

  it 'respeta el tope diario del nivel de Meta' do
    allow(TrackingDispatch::MessagingTier).to receive(:daily_limit).and_return(1)
    2.times { due(inbox_a) }

    expect(claim.size).to eq(1)
  end

  it 'no toma seguimientos de campañas pausadas ni de cuentas sin despachador' do
    paused = create(:tracking_campaign, account: account, inbox: inbox_a, status: 'paused')
    due(inbox_a, tracking_campaign: paused)
    other_account = create(:account)
    other_inbox = create(:inbox, account: other_account)
    create(:contact_tracking, account: other_account, inbox: other_inbox, contact: create(:contact, account: other_account))
      .tap { |t| t.update_columns(scheduled_for: 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations

    expect(claim).to be_empty
  end

  it 'un seguimiento ya tomado no se vuelve a tomar' do
    due(inbox_a)

    expect(claim.size).to eq(1)
    expect(claim).to be_empty
  end
end
