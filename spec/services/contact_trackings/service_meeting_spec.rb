require 'rails_helper'

RSpec.describe ContactTrackings::ServiceMeeting do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:integration) { UserCalendarIntegration.create!(account: account, user: user, google_email: 'camion@gruas.com', tokens: {}) }
  let(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, contact: create(:contact, account: account), case_type: case_type,
                       title: 'Grúa 60 t', description: 'km 14+500 → Blue Giant')
  end
  let(:inicio) { Time.zone.parse('2026-10-05 14:00 UTC') }
  let(:slot) do
    { slot: inicio, end_time: inicio + 1.hour, calendar_integration_id: integration.id, google_calendar_id: 'c60@group' }
  end
  let(:google) { instance_double(GoogleCalendarService) }

  before { allow(GoogleCalendarService).to receive(:new).and_return(google) }

  it 'aparta: tarea «[TENTATIVO]» en el calendario del equipo, sin Meet ni correos' do
    allow(google).to receive(:create_event).and_return('id' => 'evt9')

    meeting = described_class.hold!(ticket: ticket, slot: slot, title: 'Grúa 60 t', timezone: 'America/Mexico_City')
    expect(google).to have_received(:create_event)
      .with(hash_including(calendar_id: 'c60@group', summary: '[TENTATIVO] Grúa 60 t', send_updates: 'none'))
    expect(meeting.reload.attributes.slice('tentative', 'google_event_id', 'organizer_id', 'notify_client'))
      .to eq('tentative' => true, 'google_event_id' => 'evt9', 'organizer_id' => user.id, 'notify_client' => false)
    expect(meeting).to be_sync_synced
  end

  it 'si Google falla, la tarea queda pero marcada con el error' do
    allow(google).to receive(:create_event).and_raise('401')

    meeting = described_class.hold!(ticket: ticket, slot: slot, title: 'Grúa 60 t', timezone: 'America/Mexico_City')
    expect(meeting.reload).to be_sync_failed
  end

  it 'confirmar quita «[TENTATIVO]» del evento y de la tarea' do
    allow(google).to receive_messages(create_event: { 'id' => 'evt9' }, rename_event: true)
    meeting = described_class.hold!(ticket: ticket, slot: slot, title: 'Grúa 60 t', timezone: 'America/Mexico_City')

    expect(described_class.new(meeting).confirm!).to be(true)
    expect(google).to have_received(:rename_event).with('evt9', summary: 'Grúa 60 t', calendar_id: 'c60@group')
    expect(meeting.reload.attributes.slice('title', 'tentative')).to eq('title' => 'Grúa 60 t', 'tentative' => false)
  end

  it 'una renta (all_day) se aparta como evento de días completos' do
    allow(google).to receive(:create_event).and_return('id' => 'evt10')
    inicio = Time.find_zone('America/Mexico_City').local(2026, 11, 1)
    renta = slot.merge(slot: inicio, end_time: inicio + 181.days, all_day: true)

    described_class.hold!(ticket: ticket, slot: renta, title: 'Grúa 90 t', timezone: 'America/Mexico_City')
    expect(google).to have_received(:create_event)
      .with(hash_including(all_day: true, due_date: '2026-11-01', end_date: '2027-05-01'))
  end
end
