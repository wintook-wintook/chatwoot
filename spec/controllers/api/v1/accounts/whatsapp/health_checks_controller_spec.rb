# frozen_string_literal: true

require 'rails_helper'

# diag/waba F1 — pestaña «Diagnóstico» (solo administradores).
RSpec.describe 'WhatsApp health checks API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:config) { { 'api_key' => 'tok', 'phone_number_id' => 'ph1', 'business_account_id' => 'waba1', 'webhook_verify_token' => 'vt' } }
  let(:channel) do
    ch = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    ch.update_column(:provider_config, config) # rubocop:disable Rails/SkipsModelValidations # la fábrica pone su propia configuración al crear
    ch
  end
  let(:url) { "/api/v1/accounts/#{account.id}/whatsapp/health_checks/#{channel.inbox.id}" }
  let(:service) { instance_double(Whatsapp::HealthCheckService, perform: { checked_at: Time.current, checks: [{ key: 'app' }] }) }
  let(:client) { instance_double(Whatsapp::FacebookApiClient) }
  let(:ok) { instance_double(HTTParty::Response, success?: true) }

  before do
    allow(Whatsapp::HealthCheckService).to receive(:new).and_return(service)
    allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(client)
    allow(client).to receive_messages(subscribe_app: ok, subscribe_webhook: ok)
  end

  it 'sin diagnóstico todavía responde vacío; al correrlo lo guarda' do
    with_memory_cache do
      get url, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to eq('checked_at' => nil, 'checks' => [])

      post "#{url}/run", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['checks']).to eq([{ 'key' => 'app' }])

      get url, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['checks']).to eq([{ 'key' => 'app' }])
    end
  end

  it 'solo administradores (D1)' do
    create(:inbox_member, user: agent, inbox: channel.inbox)
    post "#{url}/run", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'solo bandejas de WhatsApp Cloud' do
    other = create(:channel_whatsapp, account: account, provider: 'unoapi', sync_templates: false, validate_provider_config: false)
    post "/api/v1/accounts/#{account.id}/whatsapp/health_checks/#{other.inbox.id}/run", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'Suscribir en una bandeja dada de alta a mano NO cambia la URL del webhook' do
    post "#{url}/subscribe", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(client).to have_received(:subscribe_app).with('waba1', 'tok')
    expect(client).not_to have_received(:subscribe_webhook)
  end

  it 'Suscribir en una bandeja del alta con Meta usa la URL de este servidor' do
    channel.update_column(:provider_config, config.merge('source' => 'embedded_signup')) # rubocop:disable Rails/SkipsModelValidations
    post "#{url}/subscribe", headers: admin.create_new_auth_token, as: :json

    expect(client).to have_received(:subscribe_webhook).with('waba1', 'tok', %r{/webhooks/whatsapp/}, 'vt')
  end

  it 'si Meta rechaza la suscripción, dice por qué' do
    allow(client).to receive(:subscribe_app)
      .and_return(instance_double(HTTParty::Response, success?: false, body: { error: { code: 190, message: 'x' } }.to_json))
    post "#{url}/subscribe", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to be_present
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
