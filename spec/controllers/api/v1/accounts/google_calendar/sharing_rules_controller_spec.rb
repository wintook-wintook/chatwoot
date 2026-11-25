# frozen_string_literal: true

require 'rails_helper'

# fix/calendario_google F3c — «Compartir mi calendario» con las reglas de acceso de Google.
RSpec.describe 'Google Calendar sharing rules API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:beto) { create(:user, account: account, role: :agent, name: 'Beto') }
  let(:caro) { create(:user, account: account, role: :agent, name: 'Caro') }
  let(:dani) { create(:user, account: account, role: :agent, name: 'Dani') }
  let(:twin) { create(:user, account: account, role: :agent, name: 'Gemelo') }
  let(:outsider) { create(:user, account: create(:account), role: :agent) }
  let(:google) { instance_double(GoogleCalendarService) }
  let(:url) { "/api/v1/accounts/#{account.id}/google_calendar/sharing_rules" }
  let(:acl) do
    [
      { 'role' => 'owner', 'scope' => { 'type' => 'user', 'value' => 'ana@gmail.com' } },
      { 'role' => 'reader', 'scope' => { 'type' => 'user', 'value' => 'Beto@gmail.com' } },
      { 'role' => 'owner', 'scope' => { 'type' => 'user', 'value' => 'caro@gmail.com' } },
      { 'role' => 'reader', 'scope' => { 'type' => 'user', 'value' => 'jefe@empresa.com' } },
      { 'role' => 'freeBusyReader', 'scope' => { 'type' => 'default' } }
    ]
  end
  let!(:owner_integration) { connect(owner, 'ana@gmail.com') }

  def connect(user, email)
    UserCalendarIntegration.create!(user: user, account: account, google_email: email, tokens: { 'access_token' => 't' })
  end

  before do
    connect(beto, 'beto@gmail.com')
    connect(caro, 'caro@gmail.com')
    connect(twin, 'ana@gmail.com')
    dani
    allow(GoogleCalendarService).to receive(:new).with(owner_integration).and_return(google)
    allow(google).to receive(:list_acl).and_return(acl)
    allow(google).to receive(:upsert_acl_rule)
    allow(google).to receive(:delete_acl_rule)
  end

  def headers
    owner.create_new_auth_token
  end

  describe 'GET /sharing_rules' do
    it 'muestra el permiso que le doy a cada compañero de la cuenta' do
      get url, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      rows = response.parsed_body['sharing_rules'].index_by { |r| r['agent_id'] }
      expect(rows.keys).to contain_exactly(beto.id, caro.id, dani.id, twin.id)
      expect(rows[beto.id]).to include('level' => 'details', 'status' => 'editable')
      expect(rows[caro.id]).to include('level' => 'owner', 'status' => 'owner_rule')
      expect(rows[dani.id]).to include('status' => 'not_connected')
      expect(rows[twin.id]).to include('status' => 'same_google')
    end

    it 'lista aparte a otras personas (no agentes) y las reglas generales, sin repetir compañeros ni a mí' do
      get url, headers: headers, as: :json

      body = response.parsed_body
      expect(body['others']).to eq([{ 'email' => 'jefe@empresa.com', 'level' => 'details', 'status' => 'editable' }])
      expect(body['general_rules']).to eq([{ 'type' => 'default', 'value' => nil, 'level' => 'free_busy' }])
      expect(google).to have_received(:list_acl).once
    end

    it 'pide reconectar si mi permiso de Google venció' do
      allow(GoogleCalendarService).to receive(:new).and_raise('Token refresh failed')
      get url, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('reconnect')
    end
  end

  describe 'PUT /sharing_rules/:id' do
    it 'da «Hacer cambios» (writer) sin aviso por correo y limpia la caché del dueño' do
      allow(GoogleCalendarCoworkerService).to receive(:clear_cache_for)
      put "#{url}/#{beto.id}", params: { level: 'schedule' }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(google).to have_received(:upsert_acl_rule).with('beto@gmail.com', 'writer')
      expect(GoogleCalendarCoworkerService).to have_received(:clear_cache_for).with('ana@gmail.com')
    end

    it 'Nada = quita la regla' do
      put "#{url}/#{beto.id}", params: { level: 'none' }, headers: headers, as: :json
      expect(google).to have_received(:delete_acl_rule).with('beto@gmail.com')
    end

    it 'no toca una regla «Administrar» dada desde Google' do
      put "#{url}/#{caro.id}", params: { level: 'none' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('owner_rule')
      expect(google).not_to have_received(:delete_acl_rule)
    end

    it 'rechaza compañeros sin Google, con mi mismo Google, de otra cuenta o niveles raros' do
      put "#{url}/#{dani.id}", params: { level: 'details' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('not_connected')
      put "#{url}/#{twin.id}", params: { level: 'details' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('same_google')
      put "#{url}/#{outsider.id}", params: { level: 'details' }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      put "#{url}/#{beto.id}", params: { level: 'owner' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('invalid_level')
      expect(google).not_to have_received(:upsert_acl_rule)
    end

    it 'muestra el motivo de Google si rechaza (p. ej. Workspace)' do
      allow(google).to receive(:upsert_acl_rule)
        .and_raise('Google Calendar API error 403: {"error":{"message":"Cannot share outside the domain"}}')
      put "#{url}/#{beto.id}", params: { level: 'details' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Cannot share outside the domain')
    end
  end

  describe 'PUT /sharing_rules/share_email' do
    let(:share_url) { "#{url}/share_email" }

    it 'comparte con cualquier correo (en minúsculas) sin aviso' do
      put share_url, params: { email: ' Cliente@Hotmail.com ', level: 'free_busy' }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(google).to have_received(:upsert_acl_rule).with('cliente@hotmail.com', 'freeBusyReader')
    end

    it 'Nada = quita a esa persona' do
      put share_url, params: { email: 'jefe@empresa.com', level: 'none' }, headers: headers, as: :json
      expect(google).to have_received(:delete_acl_rule).with('jefe@empresa.com')
    end

    it 'rechaza correo inválido, mi propio correo, niveles raros y reglas «Administrar»' do
      put share_url, params: { email: 'no-es-correo', level: 'details' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('invalid_email')
      put share_url, params: { email: 'ANA@gmail.com', level: 'details' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('own_email')
      put share_url, params: { email: 'x@y.com', level: 'owner' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('invalid_level')
      put share_url, params: { email: 'caro@gmail.com', level: 'none' }, headers: headers, as: :json
      expect(response.parsed_body['error']).to eq('owner_rule')
      expect(google).not_to have_received(:upsert_acl_rule)
      expect(google).not_to have_received(:delete_acl_rule)
    end
  end
end
