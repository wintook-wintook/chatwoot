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

      it 'ignora un inbox de otra cuenta y no filtra datos ajenos' do
        ajeno = create(:inbox, account: create(:account))

        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            params: { inbox_id: ajeno.id }, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['engine']['model'])
          .to eq(AiAgentAssistant::EngineConfig::DEFAULT_MODEL)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_agent_assistant/lint' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/lint" }

    it 'returns unauthorized for an unauthenticated user' do
      post url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'valida un borrador sin guardar nada' do
      expect do
        post url,
             params: { tracking_template: { name: 'Borrador', objective: 'x' * 80,
                                            complementary_prompt: "@discourse\n#{'y' * 400}" } },
             headers: agent.create_new_auth_token, as: :json
      end.not_to change(TrackingTemplate, :count)

      reglas = response.parsed_body['findings'].pluck('rule')
      expect(reglas).to include('search_swallows_prompt')
    end

    it 'no devuelve nada para un borrador bien formado' do
      post url,
           params: { tracking_template: { name: 'Borrador', inbox_id: inbox.id,
                                          objective: 'Confirmar el pago de la factura vencida u obtener fecha compromiso.',
                                          complementary_prompt: 'Eres del área de cobranza. Trato de usted.' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['findings']).to be_empty
    end

    # Al editar un Agente IA existente hay que partir del registro guardado: sus
    # archivos adjuntos y sus hermanos de versión no viajan en el formulario.
    it 'parte del Agente IA guardado cuando se pasa el id' do
      template = create(:tracking_template, account: account, inbox: inbox, name: 'Con archivo',
                                            objective: 'x' * 80)
      create(:ai_agent_attachment, tracking_template: template, name: 'catalogo')

      post url,
           params: { id: template.id,
                     tracking_template: { complementary_prompt: 'Te comparto el {{catalogo}}' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['findings'].pluck('rule')).not_to include('attachment_missing')
    end

    it 'no permite validar un Agente IA de otra cuenta' do
      ajeno = create(:tracking_template, account: create(:account), name: 'Ajeno', objective: 'x' * 80)

      post url,
           params: { id: ajeno.id, tracking_template: { complementary_prompt: 'Hola' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(TrackingTemplate.find(ajeno.id).complementary_prompt).to be_blank
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_agent_assistant/preview_prompt' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/preview_prompt" }

    it 'returns unauthorized for an unauthenticated user' do
      post url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'devuelve el prompt ensamblado de las dos rutas sin persistir nada' do
      expect do
        post url,
             params: { tracking_template: { name: 'Borrador', objective: 'Confirmar el pago de la factura.',
                                            complementary_prompt: 'Eres del área de cobranza.' } },
             headers: agent.create_new_auth_token, as: :json
      end.not_to change(ContactTracking, :count)

      body = response.parsed_body
      expect(body['scheduled']['system']).to include('Eres un asistente de seguimiento al cliente')
      expect(body['scheduled']['system']).to include('INSTRUCCIONES ADICIONALES DEL AGENTE')
      expect(body['conversational']['system']).to include('Eres un asesor de ventas para')
      expect(body['scheduled']['max_tokens']).to eq(150)
      expect(body['conversational']['max_tokens']).to eq(250)
    end

    it 'avisa cuando el prompt no llega al modelo por una directiva de búsqueda' do
      post url,
           params: { tracking_template: { name: 'Borrador', objective: 'Resolver dudas.',
                                          complementary_prompt: "@discourse\nInstrucciones largas del agente." } },
           headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['conversational']['notes']).to include('prompt_discarded')
      expect(body['conversational']['system']).not_to include('Instrucciones largas')
    end

    it 'refleja el número de intento pedido' do
      post url,
           params: { attempt: 3,
                     tracking_template: { name: 'Borrador', objective: 'Confirmar el pago.' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['scheduled']['system']).to include('intento número 3 de 3')
    end
  end
end
