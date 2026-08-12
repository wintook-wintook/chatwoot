# frozen_string_literal: true

# proyecto@ai_agent_assistant - F1
require 'rails_helper'

RSpec.describe 'AI Agent Assistant API', type: :request do
  let!(:account) { create(:account) }
  let(:agent)    { create(:user, account: account, role: :agent) }
  let(:inbox)    { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/ai_agent_assistant/capabilities' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'devuelve una entrada por capacidad registrada' do
        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['capabilities'].size).to eq(AiAgentAssistant::Capabilities.all.size)
      end

      it 'nunca expone la expresión regular al cliente' do
        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            headers: agent.create_new_auth_token, as: :json

        claves = response.parsed_body['capabilities'].flat_map(&:keys).uniq
        expect(claves).not_to include('matcher')
        expect(claves).to include('i18n_key', 'available', 'swallows_prompt')
      end

      it 'resuelve la disponibilidad contra las features de la cuenta' do
        account.enable_features!('google_calendar')
        account.disable_features!('erp_connection')

        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            headers: agent.create_new_auth_token, as: :json

        capabilities = response.parsed_body['capabilities'].index_by { |c| c['key'] }
        expect(capabilities['hoja']['available']).to be(true)
        expect(capabilities['consulta']['available']).to be(false)
      end

      it 'informa el modelo que el motor usaría en ese inbox' do
        create(:integrations_hook, account: account, inbox: inbox, app_id: 'tracking_bot',
                                   status: 'enabled', settings: { 'model_ia' => 'gpt-4o' })

        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            params: { inbox_id: inbox.id }, headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body['engine']['model']).to eq('gpt-4o')
      end

      it 'cae al modelo por defecto cuando no se pasa inbox' do
        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body['engine']['model'])
          .to eq(AiAgentAssistant::EngineConfig::DEFAULT_MODEL)
      end

      it 'ignora un inbox de otra cuenta' do
        ajeno = create(:inbox, account: create(:account))

        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            params: { inbox_id: ajeno.id }, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['engine']['model'])
          .to eq(AiAgentAssistant::EngineConfig::DEFAULT_MODEL)
      end
    end
  end
end
