# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — quien prueba solo dice qué debió responder; quien entrena revisa aparte.
RSpec.describe 'Agent Tester API — revisión' do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:tester) { create(:user, account: account, role: :agent) }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:template) { create(:tracking_template, account: account, testing: true, complementary_prompt: 'Sé amable') }
  let(:conversation) { AgentTester::Sandbox.new(account).start(template, user: tester) }
  let!(:reply) do
    AgentTester::Sandbox.new(account).say(conversation, '¿hay descuento?')
    conversation.messages.create!(account: account, inbox: conversation.inbox, message_type: :outgoing, content: 'Hay 52% de descuento')
  end

  def thumbs_down(user, params = {})
    post "#{api}/agent_tester/sessions/#{conversation.id}/feedback",
         params: { message_id: reply.id, feedback: 'La primera beca: 38%', note: 'inventó el 52%' }.merge(params),
         headers: user.create_new_auth_token, as: :json
  end

  it '👎: queda para revisión sin diagnóstico, con su prueba, y el diagnóstico se encola' do
    expect { thumbs_down(tester) }.to have_enqueued_job(AgentTester::DiagnoseJob)
    expect(response.parsed_body).to include('queued' => true)
    expect(response.parsed_body).not_to have_key('messages')

    log = AgentTestLog.last
    expect(log).to have_attributes(kind: 'pending', status: 'pending', feedback: 'La primera beca: 38%', note: 'inventó el 52%',
                                   user_id: tester.id, message_id: reply.id)
    expect(log.agent_test_case).to have_attributes(expected: 'La primera beca: 38%', bad_reply: 'Hay 52% de descuento')
    expect(reply.reload.content_attributes['agent_tester_rating']).to eq('down')
  end

  it '👎 sin «qué debió responder» no se guarda' do
    thumbs_down(tester, feedback: '')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'quien prueba no puede pedir el diagnóstico al momento; quien entrena sí' do
    allow_any_instance_of(AgentTester::Trainer).to receive(:chat).and_return('causes' => [{ 'kind' => 'model', 'why' => 'x' }]) # rubocop:disable RSpec/AnyInstance
    thumbs_down(tester, now: true)
    expect(response.parsed_body).to include('queued' => true)

    thumbs_down(admin, now: true)
    expect(response.parsed_body['messages']).to be_present
  end

  it '👍: la respuesta queda como prueba a cuidar' do
    post "#{api}/agent_tester/sessions/#{conversation.id}/good", params: { message_id: reply.id },
                                                                 headers: tester.create_new_auth_token, as: :json
    expect(AgentTestCase.last).to have_attributes(origin: 'good', messages: ['¿hay descuento?'])
    expect(reply.reload.content_attributes['agent_tester_rating']).to eq('up')
  end

  it 'el diagnóstico en segundo plano llena el mismo registro; quien probó no lo ve en su bitácora' do
    thumbs_down(tester)
    allow_any_instance_of(AgentTester::Trainer).to receive(:chat).and_return('causes' => [{ 'kind' => 'model', 'why' => 'no siguió' }]) # rubocop:disable RSpec/AnyInstance
    perform_enqueued_jobs(only: AgentTester::DiagnoseJob)

    log = AgentTestLog.last
    expect(log.kind).to eq('prompt').or eq('model')
    expect(AgentTestLog.count).to eq(1)

    get "#{api}/agent_tester/logs", headers: tester.create_new_auth_token
    expect(response.parsed_body.first).to include('kind' => 'pending', 'diagnosis' => {}, 'feedback' => 'La primera beca: 38%')
  end

  it 'revisión: las pláticas con sus 👎 y la plática mensaje por mensaje (solo quien entrena)' do
    thumbs_down(tester)
    get "#{api}/agent_tester/review", headers: admin.create_new_auth_token
    body = response.parsed_body
    expect(body['agents']).to eq([{ 'template_id' => template.id, 'name' => template.name, 'open' => 1 }])
    expect(body['conversations'].first).to include('conversation_id' => conversation.id, 'open' => 1, 'tester' => tester.name)

    get "#{api}/agent_tester/review/#{conversation.id}", headers: admin.create_new_auth_token
    mensaje = response.parsed_body['messages'].find { |m| m['id'] == reply.id }
    expect(mensaje).to include('rating' => 'down')
    expect(mensaje['logs'].first).to include('feedback' => 'La primera beca: 38%', 'diagnosing' => true)

    get "#{api}/agent_tester/review", headers: tester.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end

  it '«No es error» la saca de la revisión y su prueba ya no se corre; «Otro diagnóstico» lo encola con la nota' do
    thumbs_down(tester)
    log = AgentTestLog.last
    case_id = log.agent_test_case_id

    post "#{api}/agent_tester/logs/#{log.id}/rediagnose", params: { note: 'revisa la ficha de becas' },
                                                          headers: admin.create_new_auth_token, as: :json
    expect(AgentTester::DiagnoseJob).to have_been_enqueued.with(log.id, 'revisa la ficha de becas')

    post "#{api}/agent_tester/logs/#{log.id}/dismiss", params: { reason: 'esa beca no existe' }, headers: admin.create_new_auth_token, as: :json
    expect(log.reload).to have_attributes(status: 'dismissed', dismissed_reason: 'esa beca no existe', agent_test_case_id: nil)
    expect(AgentTestCase.exists?(case_id)).to be(false)
  end

  it '«Probar de nuevo» de varios: una sola corrida y todos quedan probando' do
    thumbs_down(tester)
    thumbs_down(tester, feedback: 'Otra cosa')
    ids = AgentTestLog.pluck(:id)

    post "#{api}/agent_tester/logs/retest_group", params: { ids: ids }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['run_ids'].size).to eq(1)
    expect(AgentTestLog.distinct.pluck(:status)).to eq(['retesting'])
  end
end
