# frozen_string_literal: true

require 'rails_helper'

# Visitas — el vendedor en «Mi ruta», «Llegué» con coordenadas, el supervisor las mueve.
RSpec.describe 'Agenda Visits API' do
  let(:account) { create(:account, locale: 'es') }
  let(:vendor) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme', address: 'Reforma 100') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:headers) { vendor.create_new_auth_token }
  let(:starts) { Time.zone.today.noon }

  def visit(attrs = {})
    CaseMeeting.create!({ account: account, contact: contact, title: 'Visita', organizer: vendor, is_visit: true,
                          starts_at: starts, ends_at: starts + 1.hour }.merge(attrs))
  end

  it 'sin dirección toma la de la organización' do
    expect(visit.location).to eq('Reforma 100')
  end

  it 'el alta desde la agenda la marca como visita' do
    post "#{api}/agenda_items", params: { title: 'Ir', contact_id: contact.id, is_visit: true, starts_at: starts, ends_at: starts + 1.hour },
                                headers: headers, as: :json

    expect(CaseMeeting.last).to have_attributes(is_visit: true, location: 'Reforma 100')
  end

  describe 'Mi ruta' do
    it 'muestra sus visitas, no las tareas agendadas normales ni las de otro' do
      mine = visit
      visit(title: 'Junta', is_visit: false)
      visit(title: 'De otro', organizer: admin)

      get "#{api}/field_visits", params: { day: Time.zone.today }, headers: headers

      visits = response.parsed_body['visits']
      expect(visits.map { |v| v['meeting']['id'] }).to eq([mine.id])
      expect(visits.first).to include('kind' => 'visit', 'state' => 'pending', 'work_address' => 'Reforma 100')
    end
  end

  describe 'el día en la hora del usuario' do
    # 8 p. m. del 30 en México son las 02:00 UTC del 31.
    let(:night) { Time.utc(2026, 10, 31, 2) }
    let(:tz) { 'America/Mexico_City' }

    it 'una visita de noche sale en su día local, en Mi ruta y en el despacho' do
      meeting = visit(starts_at: night, ends_at: night + 1.hour)

      get "#{api}/field_visits", params: { day: '2026-10-30', tz: tz }, headers: headers
      expect(response.parsed_body['visits'].map { |v| v['meeting']['id'] }).to eq([meeting.id])

      get "#{api}/field_visits", params: { day: '2026-10-31', tz: tz }, headers: headers
      expect(response.parsed_body['visits']).to eq([])

      get "#{api}/field_dispatch", params: { day: '2026-10-30', tz: tz }, headers: admin.create_new_auth_token
      expect(response.parsed_body['salespeople'].first['visits'].size).to eq(1)
    end

    it 'con una zona inválida usa la del servidor' do
      meeting = visit(starts_at: night, ends_at: night + 1.hour)

      get "#{api}/field_visits", params: { day: '2026-10-31', tz: 'Nada/Nada' }, headers: headers

      expect(response.parsed_body['visits'].map { |v| v['meeting']['id'] }).to eq([meeting.id])
    end
  end

  describe 'Llegué' do
    it 'guarda hora, latitud y longitud, y solo cuenta la primera' do
      meeting = visit

      post "#{api}/agenda_visits/#{meeting.id}/arrive", params: { lat: 19.43, lng: -99.13, accuracy: 12 }, headers: headers, as: :json
      expect(response.parsed_body['visit']['state']).to eq('working')
      expect(meeting.reload.arrival_location).to include('lat' => 19.43, 'lng' => -99.13)

      first = meeting.arrived_at
      post "#{api}/agenda_visits/#{meeting.id}/arrive", params: { lat: 1, lng: 1 }, headers: headers, as: :json
      expect(meeting.reload).to have_attributes(arrived_at: first)
      expect(meeting.arrival_location['lat']).to eq(19.43)
    end

    it 'sin permiso de ubicación llega igual' do
      meeting = visit

      post "#{api}/agenda_visits/#{meeting.id}/arrive", headers: headers, as: :json

      expect(meeting.reload).to have_attributes(arrival_location: {})
      expect(meeting.arrived_at).to be_present
    end

    it 'no marca la llegada de otro con Agenda en «solo lo suyo»' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      role.update!(areas: role.areas.merge('agenda' => 'own'))
      account.account_users.find_by(user: vendor).update!(access_role: role)
      ajena = visit(organizer: admin)

      post "#{api}/agenda_visits/#{ajena.id}/arrive", headers: headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'termina con el reporte, que muestra dónde llegó' do
      meeting = visit
      post "#{api}/agenda_visits/#{meeting.id}/arrive", params: { lat: 19.43, lng: -99.13 }, headers: headers, as: :json
      post "#{api}/task_reports", params: { item_type: 'meeting', item_id: meeting.id, content: 'Le presenté la propuesta' }, headers: headers
      patch "#{api}/agenda_items/#{meeting.id}", params: { status: 'held' }, headers: headers, as: :json

      expect(meeting.reload).to be_held
      get "#{api}/task_reports", params: { case_meeting_id: meeting.id }, headers: headers
      expect(response.parsed_body['task_reports'].first['arrival']).to include('lat' => 19.43, 'lng' => -99.13)
    end
  end

  describe 'Voy en camino' do
    it 'guarda la hora aunque el cliente no tenga conversación' do
      meeting = visit

      post "#{api}/agenda_visits/#{meeting.id}/on_my_way", params: { eta_minutes: 20 }, headers: headers, as: :json

      expect(response.parsed_body['visit']['state']).to eq('on_the_way')
    end
  end

  describe 'reporte de llegadas' do
    it 'junta vendedores y técnicos; cada quien ve las suyas según su permiso' do
      meeting = visit
      Field::AgendaVisit.new(meeting, vendor).arrive!({ 'lat' => 19.4, 'lng' => -99.1 })
      type = CaseType.create!(account: account, name: 'Orden', color: '#000000', case_class: :work_order)
      order = CaseTicket.create!(account: account, contact: contact, case_type: type, title: 'Orden')
      Field::Visit.new(order, admin).arrive!({ lat: 20.6, lng: -103.3 })

      get "#{api}/agenda_visits/arrivals", headers: admin.create_new_auth_token
      expect(response.parsed_body['arrivals'].map { |r| [r['kind'], r['lat']] }).to contain_exactly(['visit', 19.4], ['order', 20.6])

      get "#{api}/agenda_visits/arrivals", params: { user_id: vendor.id }, headers: admin.create_new_auth_token
      expect(response.parsed_body['arrivals'].size).to eq(1)
    end
  end

  describe 'órdenes de trabajo en Llegadas y Reportes' do
    let(:type) { CaseType.create!(account: account, name: 'Orden', color: '#000000', case_class: :work_order) }
    let(:order) { CaseTicket.create!(account: account, contact: contact, case_type: type, title: 'Orden', organization_id: organization.id) }
    let(:auth) { admin.create_new_auth_token }

    it 'llegar sin ubicación sale igual en Llegadas' do
      Field::Visit.new(order, admin).arrive!({})

      get "#{api}/agenda_visits/arrivals", headers: auth

      row = response.parsed_body['arrivals'].first
      expect(row).to include('kind' => 'order', 'title' => 'Orden', 'lat' => nil)
    end

    it 'terminar la visita la deja en Reportes y en las fichas, con su llegada' do
      visit_service = Field::Visit.new(order, admin)
      visit_service.arrive!({ lat: 20.6, lng: -103.3 })
      visit_service.finish!({}, { received_by: 'Ana', conformity_note: 'Todo bien', signature: nil })

      [{ user_id: admin.id }, { contact_id: contact.id }, { organization_id: organization.id }].each do |filter|
        get "#{api}/task_reports", params: filter, headers: auth
        report = response.parsed_body['task_reports'].first
        expect(report).to include('kind' => 'order', 'title' => 'Orden', 'outcome' => 'Visita terminada')
        expect(report['content']).to include('Todo bien', 'Ana')
        expect(report['arrival']).to include('lat' => 20.6)
        expect(report['service_report_url']).to include('/reporte/')
      end
    end

    it 'no duplica el reporte de la misma visita' do
      entry = Field::Visit.new(order, admin).arrive!({})
      entry.update!(ended_at: Time.current)

      2.times { Field::VisitReport.new(order, entry, admin).record! }

      expect(TaskReport.where(case_time_entry_id: entry.id).count).to eq(1)
    end
  end

  describe 'despacho' do
    let(:auth) { admin.create_new_auth_token }

    it 'el tablero muestra a los vendedores con sus visitas' do
      meeting = visit
      get "#{api}/field_dispatch", params: { day: Time.zone.today }, headers: auth

      person = response.parsed_body['salespeople'].first
      expect(person['id']).to eq(vendor.id)
      expect(person['visits'].first['meeting']['id']).to eq(meeting.id)
    end

    it 'el supervisor la cambia de persona y de hora, y su evento pasa al nuevo calendario' do
      meeting = visit(google_event_id: 'evt1', google_calendar_id: 'primary')
      mirror = instance_double(Cases::Meetings::GoogleMirrorService, cancel: true)
      allow(Cases::Meetings::GoogleMirrorService).to receive(:new).and_return(mirror)
      nuevo = starts + 2.hours

      expect do
        post "#{api}/field_dispatch/move_visit", params: { meeting_id: meeting.id, user_id: admin.id, starts_at: nuevo, day: Time.zone.today },
                                                 headers: auth, as: :json
      end.to have_enqueued_job(Cases::MeetingSyncJob).with(meeting.id, 'create')

      expect(mirror).to have_received(:cancel)
      expect(meeting.reload).to have_attributes(organizer_id: admin.id, starts_at: nuevo, ends_at: nuevo + 1.hour, google_event_id: nil)
    end
  end

  describe 'lista de verificación de una orden' do
    it 'no pide reporte por punto; una tarea de otro caso sí' do
      type = CaseType.create!(account: account, name: 'Orden', color: '#000000', case_class: :work_order)
      order = CaseTicket.create!(account: account, contact: contact, case_type: type, title: 'Orden')
      task = CaseTask.create!(account: account, case_ticket: order, title: 'Revisar', assignee: vendor)

      patch "#{api}/case_tickets/#{order.id}/tasks/#{task.id}", params: { case_task: { status: 'done' } }, headers: headers, as: :json

      expect(task.reload).to be_done
    end
  end
end
