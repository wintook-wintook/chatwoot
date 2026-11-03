# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — POST …/assistant/drafting_chat
RSpec.describe 'Asistente de Agentes IA — conversar desde cero' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/drafting_chat" }
  let(:mensajes) { [{ role: 'user', content: 'Un agente para un consultorio de psicología' }] }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: { mensaje: '¿Cómo se llama?', instrucciones: "## Quién es\nPsicóloga" }.to_json } }] }.to_json
    )
  end

  it 'no deja entrar a un agente' do
    post url, params: { messages: mensajes }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'contesta y guarda la conversación con sus instrucciones, para retomarla' do
    post url, params: { messages: mensajes }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('reply' => '¿Cómo se llama?', 'changed' => true)
    sesion = TrackingAssistantSession.find(response.parsed_body['session_id'])
    expect(sesion.instructions).to eq("## Quién es\nPsicóloga")
    expect(sesion.messages.pluck('role')).to eq(%w[user assistant])
  end

  it 'sigue la misma conversación si llega su id' do
    post url, params: { messages: mensajes }, headers: admin.create_new_auth_token, as: :json
    id = response.parsed_body['session_id']

    post url, params: { messages: mensajes, session_id: id }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['session_id']).to eq(id)
  end

  # proyecto@crear_agente_conversando FR
  describe 'con herramientas (custom_attributes assistant_tools)' do
    before do
      account.update!(custom_attributes: { 'assistant_tools' => true })
      stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { choices: [{ message: { role: 'assistant',
                                       content: { mensaje: 'Te propongo la ruta Cotizar', instrucciones: nil,
                                                  boceto: "@ruta(cotizar: cuánto cuesta): -\nprosa que no va" }.to_json } }] }.to_json
      )
    end

    it 'pregunta con herramientas, devuelve el boceto y lo guarda en la conversación' do
      post url, params: { messages: mensajes }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('routes' => '@ruta(cotizar: cuánto cuesta): -', 'tools_used' => [])
      con_herramientas = a_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL)
                         .with { |req| JSON.parse(req.body)['tools'].present? }
      expect(con_herramientas).to have_been_made
      sesion = TrackingAssistantSession.find(response.parsed_body['session_id'])
      expect(sesion.proposal['boceto']).to eq('@ruta(cotizar: cuánto cuesta): -')
    end
  end

  it 'sin la bandera no manda herramientas' do
    post url, params: { messages: mensajes }, headers: admin.create_new_auth_token, as: :json

    sin_herramientas = a_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL)
                       .with { |req| JSON.parse(req.body)['tools'].nil? }
    expect(sin_herramientas).to have_been_made
  end

  # proyecto@crear_agente_conversando FD
  describe 'las pruebas de la conversación' do
    before { account.update!(custom_attributes: { 'assistant_tools' => true }) }

    def turno(sesion_id: nil, pruebas: [])
      tools = instance_double(ContactTrackings::Assistant::DraftingChat)
      allow(ContactTrackings::Assistant::DraftingChat).to receive(:new).and_return(tools)
      allow(tools).to receive(:call).and_return(
        reply: 'Probé la ruta', instructions: 'x', changed: false, routes: '@ruta(cotizar: precio): -', tools_used: [],
        tests: pruebas
      )
      post url, params: { messages: mensajes, session_id: sesion_id }, headers: admin.create_new_auth_token, as: :json
      response.parsed_body
    end

    it 'se juntan entre turnos, cada frase con su último resultado' do
      primero = turno(pruebas: [{ frase: 'precio', cae_en: 'cotizar', estable: true }])
      segundo = turno(sesion_id: primero['session_id'],
                      pruebas: [{ frase: 'PRECIO', cae_en: 'otra', estable: false }, { frase: 'hola', cae_en: 'cotizar', estable: true }])
      expect(segundo['tests'].pluck('frase', 'cae_en')).to eq([%w[PRECIO otra], %w[hola cotizar]])
      expect(TrackingAssistantSession.find(segundo['session_id']).proposal['boceto']).to eq('@ruta(cotizar: precio): -')
    end
  end

  # proyecto@crear_agente_conversando F3
  describe 'Definición, Variables y Datos fijos' do
    before do
      stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { choices: [{ message: { content: { mensaje: 'Anoté qué sistema usa', instrucciones: nil,
                                                  definicion: { objetivo: 'Agendar demos' },
                                                  variables: [{ nombre: 'SISTEMA', valores: %w[CONTPAQi Aspel] }] }.to_json } }] }.to_json
      )
    end

    it 'devuelve las pestañas completas y las guarda en la conversación' do
      post url, params: { messages: mensajes, fields: { datos_fijos: 'EMPRESA = Kontrolya' } },
                headers: admin.create_new_auth_token, as: :json

      esperado = { 'objective' => 'Agendar demos', 'variables' => 'SISTEMA = CONTPAQi | Aspel', 'datos_fijos' => 'EMPRESA = Kontrolya' }
      expect(response.parsed_body['fields']).to eq(esperado)
      expect(TrackingAssistantSession.find(response.parsed_body['session_id']).proposal).to include(esperado)
    end

    it 'guarda lo corregido a mano sin gastar un turno (vaciar también cuenta)' do
      sesion = TrackingAssistantSession.create!(account: account, user: admin,
                                                proposal: { 'name' => 'Demo', 'variables' => 'X = A | B' })

      patch "#{url}/fields", params: { session_id: sesion.id, fields: { variables: '', objective: 'Nuevo' } },
                             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(sesion.reload.proposal).to include('name' => 'Demo', 'variables' => '', 'objective' => 'Nuevo')
      expect(a_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL)).not_to have_been_made
    end

    it 'no guarda en la conversación de otra cuenta' do
      otra = TrackingAssistantSession.create!(account: create(:account), user: admin, proposal: {})

      patch "#{url}/fields", params: { session_id: otra.id, fields: { objective: 'x' } },
                             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
