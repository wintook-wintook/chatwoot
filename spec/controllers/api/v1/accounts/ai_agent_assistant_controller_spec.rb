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

      # Es lo que consume el picker del editor desde que dejó de tener su propio
      # catálogo en JavaScript: el token exacto a insertar y qué le hace al prompt.
      it 'entrega el token insertable y el efecto de cada directiva' do
        account.case_types.create!(name: 'Soporte')

        get "/api/v1/accounts/#{account.id}/ai_agent_assistant/capabilities",
            headers: agent.create_new_auth_token, as: :json

        capabilities = response.parsed_body['capabilities'].index_by { |c| c['key'] }
        expect(capabilities['crear_ticket']['tokens'].first['token'])
          .to eq('@crear_ticket(prioridad=alta, tipo=Soporte)')
        expect(capabilities['buscar_articulo']['swallows_prompt']).to be(true)
        expect(capabilities['hoja']['swallows_prompt']).to be(false)
      end

      it 'resuelve la disponibilidad contra las features de la cuenta' do
        account.enable_features!('google_calendar')
        account.disable_features!('erp_connection')
        account.knowledge_sources.create!(source_type: 'google_sheet', name: 'Precios')

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

  describe 'GET /api/v1/accounts/{account.id}/ai_agent_assistant/patterns' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/patterns" }

    it 'returns unauthorized for an unauthenticated user' do
      get url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'devuelve los bloques con su evidencia, las reglas de forma y el esqueleto' do
      get url, headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['blocks'].size).to eq(AiAgentAssistant::PatternLibrary::BLOCKS.size)
      expect(body['blocks'].pluck('source')).to all(be_present)
      expect(body['rules'].size).to eq(7)
      expect(body['skeleton']).to include('[ROL Y LÍMITES]')
    end

    # Lo que hace útil a la biblioteca: no ofrecer lo que en este prompt no serviría.
    it 'marca como letra muerta los bloques de prompt cuando hay una búsqueda activa' do
      account.enable_features!('google_calendar')
      account.knowledge_sources.create!(source_type: 'google_doc', name: 'Manual')

      get url, params: { complementary_prompt: '@discourse' },
               headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['prompt_is_discarded']).to be(true)
      expect(body['blocks'].find { |b| b['key'] == 'doc_source' }['status']).to eq('dead_letter')
      expect(body['blocks'].find { |b| b['key'] == 'keyword_actions_pair' }['status']).to eq('ready')
    end

    it 'resuelve la disponibilidad contra las features de la cuenta' do
      account.disable_features!('erp_connection')

      get url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['blocks'].find { |b| b['key'] == 'erp_query' }['available']).to be(false)
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

  describe 'F7 — evaluación' do
    let(:draft) do
      { name: 'Cobranza', inbox_id: inbox.id, objective: 'Confirmar el pago de la factura vencida.',
        complementary_prompt: 'Eres del área de cobranza.' }
    end

    before do
      create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                                 settings: { 'api_key' => 'sk-de-prueba' })
    end

    def stub_completion(text, tokens: 30)
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { choices: [{ message: { content: text }, finish_reason: 'stop' }],
                           usage: { completion_tokens: tokens } }.to_json)
    end

    describe 'POST simulate' do
      let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/simulate" }

      it 'returns unauthorized for an unauthenticated user' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end

      it 'sin mensaje devuelve el mensaje inicial del intento' do
        stub_completion('Hola Juan, te escribo por la factura pendiente.')

        post url, params: { tracking_template: draft, attempt: 2 },
                  headers: agent.create_new_auth_token, as: :json

        body = response.parsed_body
        expect(body['text']).to include('factura')
        expect(body['max_tokens']).to eq(150)
        expect(body['would_have']).to include('consume_attempt')
      end

      it 'con mensaje contesta y clasifica, sin persistir nada' do
        stub_completion('Perfecto, lo confirmo.')

        expect do
          post url, params: { tracking_template: draft, message: 'ya la pagué' },
                    headers: agent.create_new_auth_token, as: :json
        end.to not_change(Message, :count).and not_change(ContactTracking, :count)

        expect(response.parsed_body['max_tokens']).to eq(250)
      end
    end

    describe 'POST auto_conversation' do
      let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/auto_conversation" }

      it 'returns unauthorized for an unauthenticated user' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end

      it 'corre los turnos pedidos con la personalidad elegida' do
        stub_completion('Un texto cualquiera.')

        post url, params: { tracking_template: draft, persona: 'annoyed', turns: 1 },
                  headers: agent.create_new_auth_token, as: :json

        body = response.parsed_body
        expect(body['persona']).to eq('annoyed')
        expect(body['turns']).to be_present
      end
    end

    describe 'POST replay' do
      let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/replay" }

      it 'returns unauthorized for an unauthenticated user' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end

      it 'avisa cuando el inbox no tiene conversaciones cerradas con las que comparar' do
        post url, params: { tracking_template: draft },
                  headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body['error']).to eq('no_conversations')
      end
    end

    describe 'POST compare' do
      let(:url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/compare" }

      it 'returns unauthorized for an unauthenticated user' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end

      it 'corre el mismo mensaje contra las dos versiones' do
        stub_completion('Respuesta.')

        post url,
             params: { tracking_template: draft,
                       variant: draft.merge(complementary_prompt: 'Eres del área de cobranza. Sé breve.'),
                       message: 'ya la pagué' },
             headers: agent.create_new_auth_token, as: :json

        body = response.parsed_body
        expect(body['message']).to eq('ya la pagué')
        expect(body['a']['text']).to be_present
        expect(body['b']['text']).to be_present
      end
    end
  end
end
