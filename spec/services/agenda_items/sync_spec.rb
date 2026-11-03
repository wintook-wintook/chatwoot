# frozen_string_literal: true

require 'rails_helper'

# Plan-Agenda A2 — el ida y vuelta con Google de la tarea agendada sin caso.
RSpec.describe 'Agenda: sincronización con Google' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:google) { instance_double(GoogleCalendarService) }
  let!(:integration) do
    UserCalendarIntegration.create!(account: account, user: agent, google_email: 'yo@x.com', tokens: {})
  end

  before do
    allow(GoogleCalendarService).to receive(:new).and_return(google)
    allow(Cases::Meetings::PushChannelService).to receive(:new).and_return(double(ensure_channel!: true)) # rubocop:disable RSpec/VerifiedDoubles
  end

  describe Cases::Meetings::ReconcileService do
    let!(:meeting) do
      CaseMeeting.create!(account: account, contact: contact, title: 'Cita', organizer: agent, starts_at: 2.days.from_now, ends_at: 3.days.from_now,
                          google_event_id: 'evt1', google_calendar_id: 'primary', sync_status: :synced)
    end

    it 'si cancelan en Google la tarea agendada sin caso, se cancela' do
      account.enable_features!('google_calendar')
      allow(google).to receive(:get_event).and_return(:already_gone)

      described_class.without_case(account.id, ['evt1'])

      expect(meeting.reload).to be_cancelled
    end
  end

  describe Cases::Meetings::GoogleMirrorService do
    before do
      account.enable_features!('google_calendar')
      allow(GoogleCalendarService).to receive(:meet_url_from).and_return(nil)
      allow(google).to receive(:create_event).and_return('id' => 'evt2')
    end

    def meeting(attrs = {})
      CaseMeeting.create!({ account: account, contact: contact, title: 'Cita', organizer: agent, starts_at: 1.day.from_now,
                            ends_at: 2.days.from_now, description: 'Hola' }.merge(attrs))
    end

    it 'espeja la que no tiene caso con la línea hacia Kontrolya' do
      described_class.new(meeting).create

      expect(google).to have_received(:create_event)
        .with(hash_including(description: a_string_including("Hola\n\nTarea en Kontrolya: ", "/contacts/#{contact.id}")))
    end

    it 'con invitados no pone la liga interna' do
      described_class.new(meeting(attendee_emails: ['cliente@x.com'])).create

      expect(google).to have_received(:create_event).with(hash_including(description: 'Hola'))
    end
  end

  describe Organizations::ContactRecords do
    it 'lo de la agenda se mueve con el contacto' do
      organization = Organization.create!(account: account, name: 'Acme')
      contact.update!(organization_id: organization.id)
      meeting = CaseMeeting.create!(account: account, contact: contact, title: 'Cita', starts_at: 1.day.from_now, ends_at: 2.days.from_now)
      otra = Organization.create!(account: account, name: 'Otra')

      described_class.new(contact).move!(organization.id, otra.id)

      expect(meeting.reload.organization_id).to eq(otra.id)
    end
  end

  describe Field::DispatchBoard do
    it 'una tarea agendada sin caso no vacía las órdenes sin programar' do
      CaseMeeting.create!(account: account, contact: contact, title: 'Cita', organizer: agent, starts_at: 1.day.from_now, ends_at: 2.days.from_now)
      type = CaseType.create!(account: account, name: 'Orden', color: '#000000', case_class: :work_order)
      order = CaseTicket.create!(account: account, contact: contact, case_type: type, title: 'Orden', on_site: true)
      board = described_class.new(account, account.case_tickets, Time.zone.today).send(:unscheduled_orders)

      expect(board).to include(order)
    end
  end
end
