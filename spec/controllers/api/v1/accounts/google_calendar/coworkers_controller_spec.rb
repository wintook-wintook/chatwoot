# frozen_string_literal: true

require 'rails_helper'

# fix/calendario_google F2 — compañeros vistos con la conexión de quien mira.
RSpec.describe 'Google Calendar coworkers API', type: :request do
  let(:account) { create(:account) }
  let(:viewer) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:beto) { create(:user, account: account, role: :agent, name: 'Beto') }
  let(:caro) { create(:user, account: account, role: :agent, name: 'Caro') }
  let(:dani) { create(:user, account: account, role: :agent, name: 'Dani') }
  let(:outsider) { create(:user, account: create(:account), role: :agent, name: 'Otro') }
  let(:google) { instance_double(GoogleCalendarService) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/google_calendar" }
  let!(:viewer_integration) { connect(viewer, 'ana@gmail.com') }

  def connect(user, email, acc = account)
    UserCalendarIntegration.create!(user: user, account: acc, google_email: email, tokens: { 'access_token' => 't' })
  end

  def google_answers(map)
    allow(google).to receive(:list_shared_events) do |calendar_id:, **|
      map.fetch(calendar_id) { { code: 404, access_role: nil, items: [] } }
    end
  end

  before do
    connect(beto, 'beto@gmail.com')
    connect(caro, 'caro@gmail.com')
    dani # sin Google
    connect(outsider, 'otro@gmail.com', outsider.accounts.first)
    allow(GoogleCalendarService).to receive(:new).and_return(google)
  end

  describe 'GET /coworkers' do
    it 'pide sesión' do
      get "#{base_url}/coworkers"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'pide que quien mira tenga Google conectado' do
      viewer_integration.destroy!
      get "#{base_url}/coworkers", headers: viewer.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'pide reconectar si el permiso de Google de quien mira venció' do
      allow(GoogleCalendarService).to receive(:new).and_raise('Token refresh failed: invalid_grant')
      get "#{base_url}/coworkers", headers: viewer.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('reconnect')
    end

    it 'lista a los compañeros de la cuenta con lo que cada uno compartió' do
      now = Time.current
      google_answers(
        'beto@gmail.com' => { code: 200, access_role: 'writer',
                              items: [{ 'id' => 'x', 'summary' => 'Visita',
                                        'start' => { 'dateTime' => (now - 5.minutes).iso8601 },
                                        'end' => { 'dateTime' => (now + 5.minutes).iso8601 } }] }
      )

      get "#{base_url}/coworkers", headers: viewer.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['google_email']).to eq('ana@gmail.com')
      rows = body['coworkers'].index_by { |r| r['agent_id'] }
      expect(rows.keys).to contain_exactly(beto.id, caro.id, dani.id)
      expect(rows[beto.id]).to include('access' => 'details', 'can_schedule' => true, 'busy_now' => true)
      expect(rows[caro.id]).to include('access' => 'none', 'can_schedule' => false, 'busy_now' => false)
      expect(rows[dani.id]).to include('access' => 'not_connected')
      expect(body.to_s).not_to include('beto@gmail.com')
    end

    it 'solo arma la conexión de quien mira, nunca la de un compañero' do
      google_answers({})
      get "#{base_url}/coworkers", headers: viewer.create_new_auth_token, as: :json
      expect(GoogleCalendarService).to have_received(:new).once.with(viewer_integration)
    end
  end

  describe 'GET /coworkers/events' do
    it 'devuelve eventos solo de compañeros palomeados de la misma cuenta' do
      google_answers(
        'beto@gmail.com' => { code: 200, access_role: 'freeBusyReader',
                              items: [{ 'id' => 'b1', 'start' => { 'dateTime' => '2026-11-26T08:00:00-06:00' },
                                        'end' => { 'dateTime' => '2026-11-26T09:00:00-06:00' } }] }
      )

      get "#{base_url}/coworkers/events",
          params: { agent_ids: [beto.id, outsider.id], start: '2026-11-23T00:00:00Z', end: '2026-11-30T00:00:00Z' },
          headers: viewer.create_new_auth_token

      expect(response).to have_http_status(:success)
      rows = response.parsed_body['coworkers']
      expect(rows.pluck('agent_id')).to eq([beto.id])
      expect(rows.first).to include('access' => 'free_busy')
      expect(rows.first['events'].first).to include('id' => 'b1', 'summary' => nil, 'private' => true)
      expect(rows.first).not_to have_key('google_email')
      expect(google).to have_received(:list_shared_events).once
    end

    # feat/ventana_evento_calendario F5 — lo que hace falta para cancelar o eliminar.
    it 'marca la serie, cuántos invitados tiene y si es una tarea agendada (sigue agendada)' do
      meeting = CaseMeeting.create!(account: account, title: 'Visita', organizer: beto, google_event_id: 'b1',
                                    starts_at: 1.day.from_now, ends_at: 25.hours.from_now)
      CaseMeeting.create!(account: account, title: 'Vieja', organizer: beto, google_event_id: 'b2', status: :cancelled,
                          starts_at: 1.day.from_now, ends_at: 25.hours.from_now)
      when_ = { 'start' => { 'dateTime' => '2026-11-26T08:00:00-06:00' }, 'end' => { 'dateTime' => '2026-11-26T09:00:00-06:00' } }
      google_answers(
        'beto@gmail.com' => { code: 200, access_role: 'writer',
                              items: [{ 'id' => 'b1', 'summary' => 'Visita', **when_ },
                                      { 'id' => 'b2', 'summary' => 'Vieja', **when_ },
                                      { 'id' => 's_1', 'summary' => 'Junta', 'recurringEventId' => 's', **when_,
                                        'attendees' => [{ 'email' => 'beto@gmail.com', 'organizer' => true },
                                                        { 'email' => 'x@y.com' }, { 'email' => 'sala@r.com', 'resource' => true }] }] }
      )

      get "#{base_url}/coworkers/events", params: { agent_ids: [beto.id] }, headers: viewer.create_new_auth_token

      events = response.parsed_body['coworkers'].first['events'].index_by { |e| e['id'] }
      expect(events['b1']['agenda_item']).to include('id' => meeting.id, 'title' => 'Visita', 'series' => false,
                                                     'has_client' => false)
      expect(events['b2']).not_to have_key('agenda_item')
      expect(events['s_1']).to include('recurring_event_id' => 's', 'guests' => 1)
    end
  end

  describe 'GET /availability (D1)' do
    before { allow(google).to receive(:free_busy).and_return({ 'calendars' => { 'primary' => { 'busy' => [{ 'start' => 's', 'end' => 'e' }] } } }) }

    it 'solo incluye compañeros que compartieron al menos libre/ocupado, y mi propio ocupado' do
      google_answers(
        'beto@gmail.com' => { code: 200, access_role: 'freeBusyReader',
                              items: [{ 'id' => 'b1', 'start' => { 'dateTime' => '2026-11-26T08:00:00-06:00' },
                                        'end' => { 'dateTime' => '2026-11-26T09:00:00-06:00' } }] }
      )

      get "#{base_url}/availability", headers: viewer.create_new_auth_token, as: :json

      rows = response.parsed_body['availability'].index_by { |r| r['agent_id'] }
      expect(rows.keys).to contain_exactly(viewer.id, beto.id)
      expect(rows[beto.id]['busy']).to eq([{ 'start' => '2026-11-26T08:00:00-06:00', 'end' => '2026-11-26T09:00:00-06:00' }])
      expect(GoogleCalendarService).to have_received(:new).once.with(viewer_integration)
    end

    it 'sin Google conectado no muestra el ocupado de nadie' do
      viewer_integration.destroy!
      get "#{base_url}/availability", headers: viewer.create_new_auth_token, as: :json
      expect(response.parsed_body['availability']).to eq([])
    end
  end

  # F3b — «Agendar a»: el evento va al calendario del compañero, creado con MI conexión.
  describe 'POST /events con agent_id' do
    let(:guard) { instance_double(GoogleCalendarScheduleGuard) }
    let(:beto_integration) { UserCalendarIntegration.find_by(user: beto) }
    let(:payload) { { summary: 'Visita', start_time: '2026-11-26T07:00:00-06:00', end_time: '2026-11-26T07:15:00-06:00' } }

    before do
      allow(GoogleCalendarScheduleGuard).to receive(:new).and_return(guard)
      allow(guard).to receive(:call).and_return(guard)
      allow(google).to receive(:create_event).and_return({ 'id' => 'e1' })
    end

    it 'con permiso crea en el calendario del compañero, sin invitarme' do
      allow(guard).to receive_messages(ok?: true, coworker_integration: beto_integration)
      post "#{base_url}/events", params: payload.merge(agent_id: beto.id), headers: viewer.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(google).to have_received(:create_event).with(hash_including(calendar_id: 'beto@gmail.com', attendees: []))
      expect(GoogleCalendarService).to have_received(:new).with(viewer_integration)
    end

    it 'sin permiso responde 403 con el motivo y no crea nada' do
      allow(guard).to receive_messages(ok?: false, error: 'Tu compañero no te dio permiso')
      post "#{base_url}/events", params: payload.merge(agent_id: beto.id), headers: viewer.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('Tu compañero no te dio permiso')
      expect(google).not_to have_received(:create_event)
    end

    it 'sin agent_id (o para mí) crea en mi calendario como siempre' do
      post "#{base_url}/events", params: payload.merge(agent_id: viewer.id), headers: viewer.create_new_auth_token, as: :json

      expect(google).to have_received(:create_event).with(hash_including(calendar_id: 'primary'))
      expect(GoogleCalendarScheduleGuard).not_to have_received(:new)
    end
  end
end
