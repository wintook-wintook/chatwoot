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
end
