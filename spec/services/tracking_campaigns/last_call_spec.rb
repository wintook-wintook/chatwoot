# frozen_string_literal: true

require 'rails_helper'

# Ofrecer y Reactivar — el «Último aviso»: un día antes de que termine la promoción, a quien nunca contestó, una vez;
# con la ventana abierta lo escribe la IA para ese contacto (si falla o es «Mensaje fijo», el texto).
RSpec.describe TrackingCampaigns::LastCall do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:now) { Time.find_zone('America/Mexico_City').parse("#{Date.current.iso8601} 18:00") }
  let(:campaign) do
    brief = TrackingCampaigns::Motor2Brief.brief('kind' => 'offer', 'offer_what' => 'Mantenimiento', 'valid_until' => (now.to_date + 1).iso8601,
                                                 'links' => [{ 'name' => 'Comprar', 'url' => 'https://ejemplo.com/c', 'use' => 'package' }])
    account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                       scheduled_for: 2.days.ago, brief: brief, touches: { 'attempts' => 1 })
  end

  def tracking(outcome = nil)
    contact = create(:contact, account: account, name: 'Mario López', email: "m#{SecureRandom.hex(3)}@ejemplo.com")
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: campaign,
                            conversation: conversation, scheduled_for: 1.minute.from_now, status: 'completed', max_attempts: 1,
                            attempt_count: 1, objective: 'Ofrecer', outcome: outcome, last_attempt_at: 2.days.ago)
  end

  it 'viene prendido con vigencia y toca un día antes de que termine' do
    expect(campaign.brief['last_call']).to include('on' => true, 'ai' => true)
    expect(described_class.due?(campaign, now)).to be(true)
    expect(described_class.due?(campaign, now - 2.days)).to be(false)
    expect(TrackingCampaigns::Motor2Check.new(campaign).call.find { |i| i[:key] == :last_call }[:level]).to eq('ok')
  end

  it 'le llega una vez a quien no contestó (no a quien ya dijo algo), con el texto si la IA no puede' do
    silent = tracking
    tracking('Logrado: compró')
    allow(Motor2::LateMessage).to receive(:deliver).and_return(true)

    expect(described_class.run(campaign, now)).to eq(1)
    expect(described_class.run(campaign, now)).to eq(0)
    expect(Motor2::LateMessage).to have_received(:deliver)
      .with(silent, '¡Hola Mario! La promoción de Mantenimiento termina mañana. ¿Te la aparto? https://ejemplo.com/c', template: nil).once
  end

  it 'con la ventana abierta lo escribe la IA para ese contacto' do
    silent = tracking
    allow(Motor2::LateMessage).to receive(:window_open?).and_return(true)
    writer = instance_double(TrackingCampaigns::ReminderWriter, for_contact: 'Mario, mañana termina tu promo')
    allow(TrackingCampaigns::ReminderWriter).to receive(:new).with(campaign, kind: 'last_call', pending: true).and_return(writer)
    expect(described_class.text_for(campaign, silent, now)).to eq('Mario, mañana termina tu promo')
  end
end
