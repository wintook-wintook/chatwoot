# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — CRUD de plantillas (request spec).
RSpec.describe 'WhatsApp Templates API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { channel.inbox }

  describe 'GET /api/v1/accounts/{id}/whatsapp/templates' do
    let!(:template) { create(:whatsapp_template, account: account, channel_whatsapp: channel, name: 'cobro') }

    it 'rechaza a usuarios no autenticados' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates", params: { inbox_id: inbox.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rechaza a agentes' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates",
          params: { inbox_id: inbox.id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lista las plantillas del canal para admins' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates",
          params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body.map { |t| t[:name] }).to include('cobro')
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates (DRY_RUN)' do
    before do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return('true')
    end

    let(:payload) do
      {
        inbox_id: inbox.id,
        whatsapp_template: {
          name: 'cobro_vencido', language: 'es', category: 'UTILITY',
          body_text: 'Hola {{1}}', sample_values: { body: ['Juan'] }
        }
      }
    end

    it 'crea una plantilla PENDING sin llamar a Meta' do
      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: payload, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:status]).to eq('PENDING')
      expect(body[:meta_template_id]).to start_with('dry-run-')
    end

    it 'devuelve 422 con error por campo si es inválido' do
      payload[:whatsapp_template][:name] = 'Mal Nombre'
      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: payload, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/Nombre/)
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates/sync' do
    it 'reconcilia desde Meta y devuelve el conteo' do
      allow_any_instance_of(Whatsapp::TemplateSyncService).to receive(:perform)
        .and_return(Whatsapp::TemplateSyncService::Result.new(synced: 3, created: 2, updated: 1))

      post "/api/v1/accounts/#{account.id}/whatsapp/templates/sync",
           params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include('synced' => 3, 'created' => 2, 'updated' => 1)
    end
  end

  describe 'DELETE /api/v1/accounts/{id}/whatsapp/templates/{id}' do
    it 'borra una plantilla local-only' do
      template = create(:whatsapp_template, account: account, channel_whatsapp: channel, meta_template_id: nil)

      delete "/api/v1/accounts/#{account.id}/whatsapp/templates/#{template.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(WhatsappTemplate.exists?(template.id)).to be(false)
    end
  end
end
