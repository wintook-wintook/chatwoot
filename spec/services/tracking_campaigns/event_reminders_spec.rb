# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA · Invitar — recordatorios a los que confirmaron, fin al empezar el evento y el evento de la
# audiencia aparte del evento invitado.
RSpec.describe TrackingCampaigns::EventReminders do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:event) do
    account.events.create!(name: 'Lanzamiento', starts_at: 20.hours.from_now, location: 'Hotel Fiesta', meeting_url: 'https://zoom.us/j/1')
  end
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Invitación', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                       scheduled_for: 1.day.ago, event: event, touches: { 'attempts' => 1 },
                                       brief: TrackingCampaigns::Motor2Brief.brief({ 'kind' => 'invite', 'event_id' => event.id }))
  end

  def tracking(outcome)
    contact = create(:contact, account: account, name: 'Mario López', email: "m#{SecureRandom.hex(3)}@ejemplo.com")
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: campaign,
                            conversation: conversation, scheduled_for: 1.minute.from_now, status: 'completed', max_attempts: 1,
                            attempt_count: 1, objective: 'Invitar', outcome: outcome)
  end

  it 'vienen prendidos y el que toca depende de cuánto falta' do
    expect(campaign.brief['reminders']).to include('day_before' => true, 'hour_before' => true)
    expect(described_class.due_kind(event)).to eq('day_before')
    expect(described_class.due_kind(event, event.starts_at - 30.minutes)).to eq('hour_before')
    expect(described_class.due_kind(event, event.starts_at - 2.days)).to be_nil
  end

  it 'le llega una sola vez solo a quien confirmó, con la fecha, el lugar y la liga' do
    confirmed = tracking('Logrado: confirmó')
    tracking('not_now')
    allow(Motor2::LateMessage).to receive(:deliver).and_return(true)

    expect(described_class.run(campaign)).to eq(1)
    expect(described_class.run(campaign)).to eq(0)
    expect(Motor2::LateMessage).to have_received(:deliver).once
                                                          .with(confirmed, a_string_including('Mario', 'Lanzamiento', 'Hotel Fiesta'), template: nil)
    expect(confirmed.reload.motor2_state['event_reminders']).to eq(['day_before'])

    text = described_class.text(campaign, event, confirmed, 'hour_before')
    expect(text).to include('https://zoom.us/j/1')
  end

  it 'sin fecha de fin, la campaña de Invitar termina cuando empieza el evento; la audiencia de otro evento no pisa el invitado' do
    expo = account.events.create!(name: 'Expo pasada', starts_at: 30.days.ago)
    result = TrackingCampaigns::Motor2Form.new(account, admin, { name: 'Lanzamiento', brief: { kind: 'invite', event_id: event.id },
                                                                 audience: { source: { type: 'event', event_id: expo.id } },
                                                                 event_status: 'attended' }).save
    saved = result[:campaign]
    expect(saved.ends_at).to be_within(1.second).of(event.starts_at)
    expect(saved).to have_attributes(event_id: event.id, event_status: nil)
    expect(saved.audience.dig('source', 'event_id').to_i).to eq(expo.id)
  end

  it 'la revisión avisa si en WhatsApp no hay plantilla para los recordatorios' do
    expect(described_class.check(campaign).first).to eq('ok')
    whatsapp = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
    campaign.update!(inbox: whatsapp)
    expect(described_class.check(campaign)).to include('warning')
  end
end
