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

  def tracking(outcome, status: 'completed', last_attempt_at: 2.days.ago)
    contact = create(:contact, account: account, name: 'Mario López', email: "m#{SecureRandom.hex(3)}@ejemplo.com")
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: campaign,
                            conversation: conversation, scheduled_for: 1.minute.from_now, status: status, max_attempts: 1,
                            attempt_count: 1, objective: 'Invitar', outcome: outcome, last_attempt_at: last_attempt_at)
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

  it 'con la ventana abierta lo escribe la IA para ese contacto; con «Mensaje fijo» o si la IA falla, el texto' do
    confirmed = tracking('Logrado: confirmó')
    allow(Motor2::LateMessage).to receive_messages(window_open?: true, deliver: true)
    writer = instance_double(TrackingCampaigns::ReminderWriter, for_contact: 'Mario, mañana te esperamos en Hotel Fiesta')
    allow(TrackingCampaigns::ReminderWriter).to receive(:new).and_return(writer)

    expect(described_class.text_for(campaign, event, confirmed, 'day_before', pending: false)).to eq('Mario, mañana te esperamos en Hotel Fiesta')
    allow(writer).to receive(:for_contact).and_return(nil)
    expect(described_class.text_for(campaign, event, confirmed, 'day_before', pending: false)).to include('Lanzamiento')

    campaign.update!(brief: campaign.brief.merge('reminders' => { 'day_ai' => false, 'day_text' => 'Hola {{nombre}}, mañana es {{evento}}' }))
    expect(TrackingCampaigns::EventReminderSettings.sanitize('day_ai' => false)).to include('day_ai' => false, 'day_pending_ai' => true)
    expect(described_class.text_for(campaign, event, confirmed, 'day_before', pending: false)).to eq('Hola Mario, mañana es Lanzamiento')
  end

  it 'la IA al momento: con sus datos reales y, si no la puso, la liga al final; el fijo de Dali lleva {{nombre}} y {{liga}}' do
    writer = TrackingCampaigns::ReminderWriter.new(campaign, kind: 'hour_before', pending: false)
    allow(writer).to receive_messages(available?: true, chat: { 'texto' => 'Mario, en una hora empieza **Lanzamiento**' })
    expect(writer.for_contact(tracking('Logrado: confirmó'), { 'nombre' => 'Mario', 'liga' => 'https://zoom.us/j/1' }))
      .to eq("Mario, en una hora empieza *Lanzamiento*\nhttps://zoom.us/j/1")

    draft = TrackingCampaigns::ReminderWriter.new(campaign, kind: 'day_before', pending: true)
    allow(draft).to receive_messages(available?: true, chat: { 'texto' => 'Hola {{contacto}}, mañana es {{evento}}' })
    expect(draft.draft).to eq(text: 'Hola {{nombre}}, mañana es {{evento}} {{liga}}')
  end

  it 'un día antes también a los que no han contestado (última invitación, con la liga de registro); una hora antes solo confirmados' do
    campaign.update!(brief: campaign.brief.merge('offer_goal' => 'external',
                                                 'links' => [{ 'name' => 'Registro', 'url' => 'https://zoom.us/r', 'use' => 'package' }]))
    silent = tracking(nil, status: 'scheduled')
    answered = tracking(nil)
    create(:message, account: account, inbox: inbox, conversation: answered.conversation, message_type: :incoming, content: 'Lo veo')
    just_touched = tracking(nil, last_attempt_at: 1.hour.ago)
    allow(Motor2::LateMessage).to receive(:deliver).and_return(true)

    expect(described_class.run(campaign)).to eq(1)
    expect(Motor2::LateMessage).to have_received(:deliver).with(silent, a_string_including('¿Te apartamos tu lugar?', 'https://zoom.us/r'),
                                                                template: nil)
    expect(silent.reload.scheduled_for).to be > event.starts_at # ya no salen sus toques
    expect(answered.reload.motor2_state.to_h['event_reminders']).to be_nil
    expect(just_touched.reload.motor2_state.to_h['event_reminders']).to be_nil

    expect(described_class.run(campaign, event.starts_at - 30.minutes)).to eq(0) # una hora antes: solo confirmados
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
