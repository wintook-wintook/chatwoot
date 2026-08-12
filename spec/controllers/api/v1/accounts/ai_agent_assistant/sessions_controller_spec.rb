# frozen_string_literal: true

# proyecto@ai_agent_assistant - F5
require 'rails_helper'

RSpec.describe 'AI Agent Assistant Sessions API', type: :request do
  let!(:account) { create(:account) }
  let(:agent)    { create(:user, account: account, role: :agent) }
  let(:otro)     { create(:user, account: account, role: :agent) }
  let(:inbox)    { create(:inbox, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ai_agent_assistant/sessions" }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-de-prueba' })
  end

  def stub_openai(payload)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: payload.to_json } }] }.to_json)
  end

  describe 'POST create' do
    it 'returns unauthorized for an unauthenticated user' do
      post base_url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'abre la sesión y devuelve ya el primer turno' do
      stub_openai(reply: '¿Qué tiene que pasar para darlo por cumplido?', proposals: [])

      post base_url, params: { mode: 'interview' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['mode']).to eq('interview')
      expect(body['step']).to eq('objective')
      expect(body['turn']['reply']).to be_present
      expect(body['steps'].pluck('key')).to include('knowledge')
    end

    it 'cae a entrevista si el modo no existe' do
      stub_openai(reply: 'ok', proposals: [])

      post base_url, params: { mode: 'lo-que-sea' }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['mode']).to eq('interview')
    end

    # Modo auditar: el usuario llega con el prompt que escribió en ChatGPT.
    it 'arranca el modo auditar con el prompt pegado como borrador' do
      stub_openai(reply: 'Vamos a revisarlo.', proposals: [])

      post base_url,
           params: { mode: 'audit', complementary_prompt: 'Eres un asistente muy servicial…' },
           headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['draft']['complementary_prompt']).to include('muy servicial')
    end

    it 'nunca crea ni toca un Agente IA' do
      stub_openai(reply: 'ok', proposals: [{ field: 'objective', value: 'Cobrar la factura vencida.' }])

      expect do
        post base_url, headers: agent.create_new_auth_token, as: :json
      end.not_to change(TrackingTemplate, :count)
    end
  end

  describe 'POST messages' do
    let(:session) do
      account.ai_agent_assistant_sessions.create!(user: agent, mode: 'interview', step: 'objective')
    end

    it 'devuelve el turno con la propuesta y el hallazgo del linter' do
      stub_openai(reply: 'Te propongo esto.',
                  proposals: [{ field: 'objective', value: 'Confirmar el pago de la factura vencida.' }],
                  next_step: 'audience')

      post "#{base_url}/#{session.id}/messages", params: { message: 'quiero cobrar' },
                                                 headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['turn']['proposals'].first['field']).to eq('objective')
      expect(body['step']).to eq('audience')
      expect(body['messages'].pluck('role')).to eq(%w[user assistant])
    end

    it 'no deja entrar en la sesión de otro agente' do
      ajena = account.ai_agent_assistant_sessions.create!(user: otro, mode: 'interview')

      post "#{base_url}/#{ajena.id}/messages", params: { message: 'hola' },
                                               headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST apply' do
    let(:session) do
      account.ai_agent_assistant_sessions.create!(
        user: agent, mode: 'interview', step: 'objective',
        proposals: [{ 'field' => 'objective', 'value' => 'Confirmar el pago de la factura vencida.' },
                    { 'field' => 'name', 'value' => 'WhatsApp · Cobranza' }]
      )
    end

    # La regla del módulo: por campo, nunca en bloque.
    it 'aplica solo los campos aceptados y deja el resto pendiente' do
      post "#{base_url}/#{session.id}/apply", params: { fields: ['objective'] },
                                              headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['applied']).to eq(['objective'])
      expect(body['draft']['objective']).to eq('Confirmar el pago de la factura vencida.')
      expect(body['draft']).not_to have_key('name')
      expect(body['proposals'].pluck('field')).to eq(['name'])
    end

    it 'devuelve el diff de lo que cambió en el borrador' do
      post "#{base_url}/#{session.id}/apply", params: { fields: %w[objective name] },
                                              headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['diff'].pluck('field')).to contain_exactly('objective', 'name')
    end

    it 'ignora campos que no son del Agente IA' do
      post "#{base_url}/#{session.id}/apply", params: { fields: ['superpoder'] },
                                              headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['applied']).to be_empty
    end

    it 'sigue sin escribir en el Agente IA' do
      template = create(:tracking_template, account: account, name: 'Cobranza', objective: 'x' * 80)
      session.update!(tracking_template: template)

      expect do
        post "#{base_url}/#{session.id}/apply", params: { fields: ['objective'] },
                                                headers: agent.create_new_auth_token, as: :json
      end.not_to(change { template.reload.objective })
    end
  end

  describe 'PATCH update — cambiar de modo' do
    let(:session) do
      account.ai_agent_assistant_sessions.create!(
        user: agent, mode: 'interview', step: 'channel',
        draft: { 'objective' => 'Confirmar el pago de la factura vencida.' },
        messages: [{ 'role' => 'user', 'content' => 'quiero cobrar' },
                   { 'role' => 'assistant', 'content' => '¿por qué canal?' }]
      )
    end

    # El defecto que motivó esto: cambiar de pestaña tiraba la entrevista a la basura.
    it 'conserva la conversación y el borrador' do
      patch "#{base_url}/#{session.id}", params: { mode: 'audit' },
                                         headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['mode']).to eq('audit')
      expect(body['draft']['objective']).to eq('Confirmar el pago de la factura vencida.')
      expect(body['messages'].pluck('content')).to include('quiero cobrar', '¿por qué canal?')
    end

    it 'deja una marca del cambio en el hilo, sin llamar al modelo' do
      patch "#{base_url}/#{session.id}", params: { mode: 'tweak' },
                                         headers: agent.create_new_auth_token, as: :json

      marca = response.parsed_body['messages'].last
      expect(marca['role']).to eq('system')
      expect(marca['mode']).to eq('tweak')
      expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/chat/completions')
    end

    it 'no pierde el paso de la entrevista al ir y volver' do
      patch "#{base_url}/#{session.id}", params: { mode: 'audit' },
                                         headers: agent.create_new_auth_token, as: :json
      patch "#{base_url}/#{session.id}", params: { mode: 'interview' },
                                         headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['step']).to eq('channel')
    end

    it 'ignora un modo inventado' do
      patch "#{base_url}/#{session.id}", params: { mode: 'telepatía' },
                                         headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['mode']).to eq('interview')
    end

    it 'no deja cambiar el modo de la sesión de otro agente' do
      ajena = account.ai_agent_assistant_sessions.create!(user: otro, mode: 'interview')

      patch "#{base_url}/#{ajena.id}", params: { mode: 'audit' },
                                       headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'las marcas de modo no viajan al modelo' do
    it 'el historial que recibe OpenAI solo lleva turnos de la conversación' do
      session = account.ai_agent_assistant_sessions.create!(user: agent, mode: 'interview')
      session.append_message('user', 'hola')
      session.append_message('system', '', mode: 'audit')
      session.append_message('assistant', 'dime')
      session.save!

      expect(session.history_for_model.pluck(:role)).to eq(%w[user assistant])
    end
  end

  describe 'GET index y DELETE' do
    it 'lista solo las sesiones del agente que pregunta' do
      mia = account.ai_agent_assistant_sessions.create!(user: agent, mode: 'interview')
      account.ai_agent_assistant_sessions.create!(user: otro, mode: 'interview')

      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['sessions'].pluck('id')).to eq([mia.id])
    end

    # Es lo que permite retomar: el asistente del editor trabaja sobre un Agente IA
    # concreto y el de la página sobre ninguno; no deben cruzarse.
    it 'separa las sesiones por el Agente IA sobre el que trabajan' do
      template = create(:tracking_template, account: account, name: 'Cobranza', objective: 'x' * 80)
      del_editor = account.ai_agent_assistant_sessions.create!(user: agent, mode: 'audit',
                                                               tracking_template: template)
      suelta = account.ai_agent_assistant_sessions.create!(user: agent, mode: 'interview')

      get base_url, params: { tracking_template_id: template.id },
                    headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['sessions'].pluck('id')).to eq([del_editor.id])

      get base_url, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['sessions'].pluck('id')).to eq([suelta.id])
    end

    it 'descarta una sesión' do
      session = account.ai_agent_assistant_sessions.create!(user: agent, mode: 'interview')

      delete "#{base_url}/#{session.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(AiAgentAssistantSession.exists?(session.id)).to be(false)
    end
  end

  describe 'sin integración de OpenAI' do
    it 'abre la sesión igual y dice por qué no hay respuesta' do
      account.hooks.find_by(app_id: 'openai').destroy!

      post base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['turn']['error']).to eq('openai_not_configured')
    end
  end
end
