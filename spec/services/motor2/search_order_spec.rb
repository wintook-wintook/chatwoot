# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 › orden de consulta en cascada: lo propio y rápido primero; antes de una fuente lenta (foro,
# CONTPAQi) se revisa si lo encontrado ya lo contesta y, si sí, no se consulta.
RSpec.describe Motor2::Search do
  let(:account) { create(:account) }
  let(:contpaq) do
    account.knowledge_sources.create!(source_type: 'contpaq_support', name: 'CONTPAQi', status: 'active',
                                      config: { 'base_url' => 'https://contpaq.test', 'client_id' => 'x', 'client_secret' => 'y',
                                                'token_url' => 'https://contpaq.test/token', 'scope' => 'z' })
  end
  let(:keys) { ["contpaq_support:#{contpaq.id}"] }
  let(:canned_hit) { { results: [{ codigo: 'timbrar', informacion: '1. Abre la factura. 2. Timbrar.' }] } }

  before do
    allow_any_instance_of(AiFollowUps::KnowledgeSearch).to receive_messages(canned_available?: true, canned: canned_hit) # rubocop:disable RSpec/AnyInstance
    allow(Contpaq::ServiceAgent).to receive(:new).and_return(instance_double(Contpaq::ServiceAgent,
                                                                             answer: Contpaq::ServiceAgent::Result.new(answer: 'De CONTPAQi')))
  end

  it 'sin orden de la empresa: predefinidas primero y CONTPAQi al final' do
    expect(described_class.new(account, keys).sources.map(&:kind)).to eq(%w[canned contpaq_support])
  end

  it 'con el orden de la empresa (las predefinidas en la lista), ese orden' do
    expect(described_class.new(account, keys + ['canned_response']).sources.map(&:kind)).to eq(%w[contpaq_support canned])
  end

  it 'si las predefinidas ya lo contestan exacto, no le pregunta a CONTPAQi' do
    allow_any_instance_of(Motor2::ResultCheck).to receive(:call).and_return({ 'tipo' => 'exacta', 'usar' => [0] }) # rubocop:disable RSpec/AnyInstance
    search = described_class.new(account, keys)
    found = search.call('¿cómo timbro?')

    expect(found.pluck(:fuente)).to eq(['Respuestas predefinidas'])
    expect(Contpaq::ServiceAgent).not_to have_received(:new)
    expect(search.last_check).to include('tipo' => 'exacta')
  end

  it 'si no lo contestan, sigue con CONTPAQi' do
    allow_any_instance_of(Motor2::ResultCheck).to receive(:call).and_return({ 'tipo' => 'ninguna', 'usar' => [] }) # rubocop:disable RSpec/AnyInstance
    found = described_class.new(account, keys).call('¿cómo timbro?')
    expect(found.pluck(:fuente)).to eq(['Respuestas predefinidas', 'CONTPAQi'])
  end
end
