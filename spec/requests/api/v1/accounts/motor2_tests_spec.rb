# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — pruebas guardadas, el entrenador y arreglar una predefinida.
RSpec.describe 'Motor2 Tests API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:template) { create(:tracking_template, account: account, engine: '2') }
  let(:api) { "/api/v1/accounts/#{account.id}/motor2_agents/#{template.id}/tests" }
  let(:turns) { [{ role: 'user', content: '¿Becas?' }, { role: 'assistant', content: 'Sí' }, { role: 'system', content: 'x' }] }

  it 'guarda la plática como prueba (sin mensajes que no son del cliente o del agente) y la borra' do
    post api, params: { name: 'Becas', turns: turns, expected: 'Solo una beca' }, headers: admin.create_new_auth_token, as: :json
    test = Motor2Test.last
    expect(test).to have_attributes(name: 'Becas', origin: 'manual', expected: 'Solo una beca')
    expect(test.turns.pluck('role')).to eq(%w[user assistant])

    get api, headers: admin.create_new_auth_token
    expect(response.parsed_body.first['name']).to eq('Becas')

    delete "#{api}/#{test.id}", headers: admin.create_new_auth_token
    expect(Motor2Test.exists?(test.id)).to be(false)
  end

  it 'el 👎 llega al entrenador' do
    allow_any_instance_of(Motor2::Trainer).to receive(:call).and_return({ messages: [{ kind: 'question', text: '¿Seguro?' }] }) # rubocop:disable RSpec/AnyInstance
    post "#{api}/correct", params: { messages: turns, reply: 'Sí', feedback: 'No' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['messages']).to eq([{ 'kind' => 'question', 'text' => '¿Seguro?' }])
  end

  it 'arregla una respuesta predefinida de la cuenta' do
    canned = create(:canned_response, account: account, short_code: 'becas', content: 'Becas de 20% y 35%')
    post "#{api}/fix_source", params: { canned_id: canned.id, content: 'Beca de 20%' }, headers: admin.create_new_auth_token, as: :json
    expect(canned.reload.content).to eq('Beca de 20%')
  end
end
