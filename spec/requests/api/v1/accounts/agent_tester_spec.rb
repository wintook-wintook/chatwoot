# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — API: plática, 👎, aplicar (2.0), lotes, corridas y permisos.
RSpec.describe 'Agent Tester API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:template) do
    create(:tracking_template, account: account, engine: '2', testing: true, motor2: { 'instructions' => 'Atiendes alumnos.' })
  end

  it 'abre una plática, el cliente escribe y se leen las respuestas' do
    post "#{api}/agent_tester/sessions", params: { template_id: template.id }, headers: admin.create_new_auth_token, as: :json
    session = response.parsed_body
    expect(session).to include('engine' => '2', 'template_id' => template.id)

    post "#{api}/agent_tester/sessions/#{session['conversation_id']}/say", params: { content: 'Hola' },
                                                                           headers: admin.create_new_auth_token, as: :json
    get "#{api}/agent_tester/sessions/#{session['conversation_id']}", params: { after: response.parsed_body['message_id'] },
                                                                      headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('messages' => [], 'tracking_status' => 'active')
  end

  it 'aplica la corrección de prompt de un 2.0 que propuso el entrenador' do
    log = AgentTestLog.create!(account: account, tracking_template: template, user: admin, engine: '2', kind: 'prompt',
                               diagnosis: { 'cause' => { 'field' => 'instructions', 'find' => '', 'replace' => 'Una beca a la vez.' } })
    post "#{api}/agent_tester/apply", params: { log_id: log.id }, headers: admin.create_new_auth_token, as: :json
    expect(template.reload.motor2['instructions']).to eq("Atiendes alumnos.\nUna beca a la vez.")
  end

  it 'lotes: crear, agregar prueba y correrla contra un agente' do
    post "#{api}/agent_test_batches", params: { name: 'Becas' }, headers: admin.create_new_auth_token, as: :json
    batch_id = response.parsed_body['id']
    post "#{api}/agent_test_batches/#{batch_id}/cases", params: { name: 'Precio', messages: ['¿Cuánto cuesta?', ''], expected: 'Da el precio' },
                                                        headers: admin.create_new_auth_token, as: :json
    expect(AgentTestCase.last.messages).to eq(['¿Cuánto cuesta?'])

    expect do
      post "#{api}/agent_test_batches/#{batch_id}/run", params: { template_id: template.id }, headers: admin.create_new_auth_token, as: :json
    end.to have_enqueued_job(AgentTester::RunJob)
    get "#{api}/agent_test_batches/runs", headers: admin.create_new_auth_token
    expect(response.parsed_body.first).to include('batch' => 'Becas', 'status' => 'queued', 'total' => 1)
  end

  it 'la corrida guarda el resultado de cada prueba' do
    batch = AgentTestBatch.create!(account: account, name: 'Becas')
    batch.cases.create!(account: account, name: 'Precio', messages: ['¿Cuánto?'], expected: 'Da el precio')
    run = batch.runs.create!(account: account, tracking_template: template)
    allow_any_instance_of(AgentTester::ConversationRunner).to receive(:run).and_return({ name: 'Precio', ok: true, reason: 'Lo da' }) # rubocop:disable RSpec/AnyInstance
    AgentTester::RunJob.perform_now(run.id)
    expect(run.reload).to have_attributes(status: 'done', passed: 1, total: 1)
  end

  it 'avisa si el agente 1.0 cambió después de abrir la plática' do
    old = create(:tracking_template, account: account, testing: true, complementary_prompt: 'Versión 1')
    post "#{api}/agent_tester/sessions", params: { template_id: old.id }, headers: admin.create_new_auth_token, as: :json
    conversation_id = response.parsed_body['conversation_id']
    old.update!(complementary_prompt: 'Versión 2')
    get "#{api}/agent_tester/sessions/#{conversation_id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['outdated']).to be(true)
  end

  it 'guardar como prueba (manual) va solo al lote del agente y del día' do
    post "#{api}/agent_tester/sessions", params: { template_id: template.id }, headers: admin.create_new_auth_token, as: :json
    conversation_id = response.parsed_body['conversation_id']
    post "#{api}/agent_tester/sessions/#{conversation_id}/say", params: { content: '¿Cuánto cuesta?' }, headers: admin.create_new_auth_token,
                                                                as: :json
    post "#{api}/agent_tester/sessions/#{conversation_id}/save_case", params: { expected: 'Da el precio' },
                                                                      headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['saved_in']).to start_with("Pruebas · #{template.name} · ")
    expect(AgentTestCase.last).to have_attributes(messages: ['¿Cuánto cuesta?'], expected: 'Da el precio', origin: 'manual')
  end

  it 'el combo trae solo los agentes «En prueba»; quien cambia agentes los prende y apaga' do
    template
    other = create(:tracking_template, account: account, name: 'Sin probar')
    get "#{api}/agent_tester/agents", headers: admin.create_new_auth_token
    expect(response.parsed_body['agents'].pluck('id')).to eq([template.id])
    expect(response.parsed_body['can_edit']).to be(true)

    post "#{api}/agent_tester/agents/#{other.id}/testing", params: { on: true }, headers: admin.create_new_auth_token, as: :json
    expect(other.reload.testing).to be(true)
  end

  it 'un agente que no está en prueba no se puede probar' do
    other = create(:tracking_template, account: account)
    post "#{api}/agent_tester/sessions", params: { template_id: other.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  context 'with un usuario que no cambia agentes' do
    it 'prueba y guarda pruebas, pero no aplica correcciones ni prende «En prueba»; en la bitácora solo ve las suyas' do
      post "#{api}/agent_tester/sessions", params: { template_id: template.id }, headers: agent_user.create_new_auth_token, as: :json
      conversation_id = response.parsed_body['conversation_id']
      post "#{api}/agent_tester/sessions/#{conversation_id}/say", params: { content: 'Hola' }, headers: agent_user.create_new_auth_token,
                                                                  as: :json
      expect(response).to have_http_status(:ok)
      get "#{api}/agent_tester/agents", headers: agent_user.create_new_auth_token
      expect(response.parsed_body['can_edit']).to be(false)

      AgentTestLog.create!(account: account, tracking_template: template, user: admin, engine: '1', kind: 'prompt')
      mine = AgentTestLog.create!(account: account, tracking_template: template, user: agent_user, engine: '1', kind: 'prompt')
      get "#{api}/agent_tester/logs", headers: agent_user.create_new_auth_token
      expect(response.parsed_body.pluck('id')).to eq([mine.id])
      get "#{api}/agent_tester/sessions/#{conversation_id}/history", headers: agent_user.create_new_auth_token
      expect(response.parsed_body['messages'].pluck('content')).to include('Hola')

      [[:post, 'agent_tester/apply'], [:post, "agent_tester/agents/#{template.id}/testing"],
       [:get, 'agent_test_batches']].each do |verb, path|
        send(verb, "#{api}/#{path}", headers: agent_user.create_new_auth_token, as: :json)
        expect(response).to have_http_status(:forbidden).or have_http_status(:unauthorized)
      end
    end

    it 'no ve las pláticas de prueba de otros' do
      post "#{api}/agent_tester/sessions", params: { template_id: template.id }, headers: admin.create_new_auth_token, as: :json
      get "#{api}/agent_tester/sessions/#{response.parsed_body['conversation_id']}", headers: agent_user.create_new_auth_token
      expect(response).to have_http_status(:not_found)
    end
  end
end
