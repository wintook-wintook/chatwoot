# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — una prueba guardada: contesta hasta el último mensaje del cliente y el juez decide.
RSpec.describe Motor2::TestRunner do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account, engine: '2') }
  let(:test) do
    Motor2Test.create!(account: account, tracking_template: template, name: 'Becas', expected: 'Solo la de 20%',
                       turns: [{ role: 'user', content: '¿Becas?' }, { role: 'assistant', content: 'Mala' }])
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::Runner).to receive(:complete) # rubocop:disable RSpec/AnyInstance
      .and_return({ 'role' => 'assistant', 'content' => 'Tenemos una beca para ti.' })
  end

  it 'guarda el resultado con la respuesta y el motivo del juez' do
    runner = described_class.new(template)
    allow(runner).to receive(:chat).and_return({ 'ok' => true, 'reason' => 'Da solo una beca' })
    runner.run(test)
    expect(test.reload.last_run).to include('ok' => true, 'reply' => 'Tenemos una beca para ti.', 'reason' => 'Da solo una beca')
  end
end
