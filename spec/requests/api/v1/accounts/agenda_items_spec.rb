# frozen_string_literal: true

require 'rails_helper'

# Plan-Agenda — las tareas agendadas del calendario: las mismas de los casos, con su
# contacto y organización, y ligadas a un evento de Google si lo hay.
RSpec.describe 'Agenda Items API' do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, title: 'Caso', organization_id: organization.id) }
  let(:base) { "/api/v1/accounts/#{account.id}/agenda_items" }
  let(:headers) { agent.create_new_auth_token }

  def create_item(params)
    post base, params: params, headers: headers, as: :json
    response.parsed_body
  end

  def meeting_params(attrs = {})
    { title: 'Visita', starts_at: 1.day.from_now, ends_at: 25.hours.from_now }.merge(attrs)
  end

  describe 'POST alta' do
    it 'crea la tarea agendada solo con su contacto, le pone la organización y la manda a Google' do
      expect { create_item(meeting_params(contact_id: contact.id)) }.to have_enqueued_job(Cases::MeetingSyncJob)

      expect(response).to have_http_status(:created)
      expect(CaseMeeting.last).to have_attributes(case_ticket_id: nil, contact_id: contact.id, organization_id: organization.id,
                                                  organizer_id: agent.id, folio: 'R001')
    end

    it 'sin cliente es interna, y puede ser para otra persona' do
      tecnico = create(:user, account: account, role: :agent)
      create_item(meeting_params(assignee_id: tecnico.id))

      expect(CaseMeeting.last).to have_attributes(contact_id: nil, organization_id: nil, case_ticket_id: nil, organizer_id: tecnico.id)
    end

    it 'no acepta un contacto de otra cuenta' do
      create_item(meeting_params(contact_id: create(:contact).id))

      expect(response).to have_http_status(:not_found)
    end

    it 'con caso queda dentro del caso, sin contacto propio, y entra a su bitácora' do
      body = create_item(meeting_params(case_ticket_id: ticket.id))

      expect(ticket.case_meetings.first).to have_attributes(contact_id: nil, organization_id: nil)
      expect(body['agenda_item']['contact']['id']).to eq(contact.id)
      expect(ticket.case_events.where(event_type: :meeting_scheduled).count).to eq(1)
    end
  end

  describe 'desde un evento de Google' do
    let(:google) { instance_double(GoogleCalendarService) }
    let(:timed_event) do
      { 'id' => 'evt1', 'summary' => 'Comida', 'description' => "Hablar\n\nTarea en Kontrolya: http://x",
        'start' => { 'dateTime' => '2026-11-10T14:00:00-06:00' }, 'end' => { 'dateTime' => '2026-11-10T15:00:00-06:00' },
        'attendees' => [{ 'email' => 'yo@x.com', 'self' => true }, { 'email' => 'cliente@x.com' }] }
    end

    before do
      UserCalendarIntegration.create!(account: account, user: agent, google_email: 'yo@x.com', tokens: {})
      allow(GoogleCalendarService).to receive(:new).and_return(google)
      allow(GoogleCalendarService).to receive(:meet_url_from).and_return(nil)
    end

    it 'crea la tarea agendada con el mismo evento, sin duplicarlo en Google' do
      allow(google).to receive(:get_event).and_return(timed_event)

      expect do
        create_item(google_event_id: 'evt1', contact_id: contact.id, case_ticket_id: ticket.id)
      end.not_to have_enqueued_job(Cases::MeetingSyncJob)

      expect(ticket.case_meetings.first).to have_attributes(title: 'Comida', description: 'Hablar', google_event_id: 'evt1', sync_status: 'synced',
                                                            attendee_emails: ['cliente@x.com'])
    end

    it 'un evento de todo el día se queda solo en Google' do
      allow(google).to receive(:get_event).and_return('id' => 'evt2', 'summary' => 'Cierre', 'start' => { 'date' => '2026-11-10' })

      expect { create_item(google_event_id: 'evt2', contact_id: contact.id) }.not_to change(CaseMeeting, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no liga dos veces el mismo evento' do
      allow(google).to receive(:get_event).and_return(timed_event)
      create_item(google_event_id: 'evt1', contact_id: contact.id)
      create_item(google_event_id: 'evt1', contact_id: contact.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(CaseMeeting.where(google_event_id: 'evt1').count).to eq(1)
    end
  end

  describe 'PATCH y ligar a un caso' do
    def cita(attrs = {})
      CaseMeeting.create!({ account: account, contact: contact, title: 'Sin caso', organizer: agent,
                            starts_at: 1.day.from_now, ends_at: 25.hours.from_now }.merge(attrs))
    end

    it 'mover la fecha se lleva a Google' do
      meeting = cita

      expect do
        patch "#{base}/#{meeting.id}", params: { starts_at: 2.days.from_now, ends_at: 49.hours.from_now }, headers: headers, as: :json
      end.to have_enqueued_job(Cases::MeetingSyncJob)
    end

    it 'la liga a un caso y toma el consecutivo del caso' do
      CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Previa', starts_at: 1.day.from_now, ends_at: 25.hours.from_now)
      meeting = cita

      patch "#{base}/#{meeting.id}", params: { case_ticket_id: ticket.id }, headers: headers, as: :json

      expect(meeting.reload).to have_attributes(case_ticket_id: ticket.id, contact_id: nil, organization_id: nil, sequence: 2)
    end

    it 'con Agenda en «solo lo suyo» no toca la de otro' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      role.update!(areas: role.areas.merge('agenda' => 'own'))
      account.account_users.find_by(user: agent).update!(access_role: role)
      ajena = cita(organizer: create(:user, account: account))

      patch "#{base}/#{ajena.id}", params: { title: 'Mía' }, headers: headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET' do
    def cita(title, organizer, starts_at)
      CaseMeeting.create!(account: account, contact: contact, title: title, organizer: organizer, starts_at: starts_at, ends_at: starts_at + 1.hour)
    end

    it 'lista lo mío del rango, con su contacto y organización, y sin las tareas de un día' do
      CaseTask.create!(account: account, case_ticket: ticket, title: 'De un día', assignee: agent, due_at: 1.day.from_now)
      cita('Mía', agent, 1.day.from_now)
      cita('Lejos', agent, 40.days.from_now)
      cita('Ajena', create(:user, account: account), 1.day.from_now)

      get base, params: { start: Time.current.iso8601, end: 7.days.from_now.iso8601 }, headers: headers

      items = response.parsed_body['agenda_items']
      expect(items.pluck('title')).to eq(['Mía'])
      expect(items.first['organization']['id']).to eq(organization.id)
    end

    it 'el combo trae los casos abiertos del contacto o de su organización' do
      colega = create(:contact, account: account, organization_id: organization.id)
      de_colega = CaseTicket.create!(account: account, contact: colega, title: 'De la empresa', organization_id: organization.id)
      ticket
      CaseTicket.create!(account: account, contact: contact, title: 'Cerrado', status: :closed)

      get "#{base}/cases", params: { contact_id: contact.id, organization_id: organization.id }, headers: headers

      expect(response.parsed_body['cases'].pluck('id')).to contain_exactly(ticket.id, de_colega.id)
    end
  end

  describe 'la bandeja de tareas' do
    it 'la tarea agendada sin caso sale en Mi día y en la ficha del contacto' do
      meeting = CaseMeeting.create!(account: account, contact: contact, title: 'Cita', organizer: agent,
                                    starts_at: Time.current.change(hour: 12), ends_at: Time.current.change(hour: 13))

      get "/api/v1/accounts/#{account.id}/case_tasks", params: { mode: 'my_day' }, headers: headers
      expect(response.parsed_body['meta']['agenda'].pluck('id')).to eq([meeting.id])

      get "/api/v1/accounts/#{account.id}/case_tasks", params: { contact_id: contact.id, assignee_id: 'all' }, headers: headers
      expect(response.parsed_body['case_tasks'].first).to include('item_type' => 'meeting', 'id' => meeting.id)
    end

    it 'ordenar por caso no esconde las que no tienen' do
      CaseMeeting.create!(account: account, contact: contact, title: 'Sin caso', organizer: agent, starts_at: 1.day.from_now,
                          ends_at: 25.hours.from_now)

      get "/api/v1/accounts/#{account.id}/case_tasks", params: { item_type: 'meeting', sort_by: 'ticket' }, headers: headers

      expect(response.parsed_body['case_tasks'].pluck('title')).to eq(['Sin caso'])
    end
  end
end
