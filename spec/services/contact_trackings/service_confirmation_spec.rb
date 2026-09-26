require 'rails_helper'

RSpec.describe ContactTrackings::ServiceConfirmation do
  let(:account) { create(:account) }
  let(:integration) do
    UserCalendarIntegration.create!(account: account, user: create(:user, account: account), google_email: 'a@b.com', tokens: {})
  end
  let(:tracking) do
    create(:contact_tracking, account: account, appointment_status: 'tentative', appointment_event_id: 'evt1',
                              appointment_calendar_id: integration.id, appointment_calendar_gid: 'c64',
                              appointment_at: Time.find_zone('America/Mexico_City').local(2026, 9, 28, 9))
  end
  let(:google) { instance_double(GoogleCalendarService) }

  before { allow(GoogleCalendarService).to receive(:new).and_return(google) }

  it '.requires_payment?' do
    expect(described_class.requires_payment?('- -> @confirmar_servicio(requiere=pago)')).to be(true)
    expect(described_class.requires_payment?('- -> @confirmar_servicio')).to be(false)
  end

  it 'confirmar quita «[TENTATIVO]» del evento sin avisar a los invitados y lo deja en firme' do
    allow(google).to receive(:get_event).with('evt1', calendar_id: 'c64').and_return('summary' => '[TENTATIVO] Cita con Ana')
    allow(google).to receive(:rename_event)

    expect(described_class.new(tracking).confirm!).to be(true)
    expect(google).to have_received(:rename_event).with('evt1', calendar_id: 'c64', summary: 'Cita con Ana')
    expect(tracking.reload.attributes.slice('appointment_status', 'outcome'))
      .to eq('appointment_status' => 'confirmed', 'outcome' => 'appointment')
  end

  it 'si el evento ya no existe, no lo da por confirmado' do
    allow(google).to receive(:get_event).and_return(:already_gone)

    expect(described_class.new(tracking).confirm!).to be(false)
    expect(tracking.reload.appointment_status).to eq('tentative')
  end

  it 'dice cuándo es el servicio' do
    expect(described_class.new(tracking).when_text('America/Mexico_City')).to eq('lunes 28 de septiembre a las 09:00')
  end

  it 'solo está abierto si está apartado o esperando el pago' do
    expect(described_class.new(tracking).open?).to be(true)
    tracking.update!(appointment_status: 'confirmed')
    expect(described_class.new(tracking).open?).to be(false)
  end
end
