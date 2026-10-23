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
end
