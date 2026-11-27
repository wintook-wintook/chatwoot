# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — lo que el agente tuvo a la vista, para revisar datos inventados.
RSpec.describe AgentTester::Seen do
  let(:account) { create(:account) }
  let(:source) { create(:knowledge_source, account: account) }
  let(:template) { create(:tracking_template, account: account, complementary_prompt: 'Teléfono: 55 6857 4646') }

  it 'junta el Entrenamiento, la plática y las fuentes de la traza (aunque su título venga recortado)' do
    create(:knowledge_item, account: account, knowledge_source: source, title: 'Plan Empresarial — Precio y promociones largas',
                            content: 'Precio $3,221')
    traza = { 'engine' => '1', 'fragmentos' => [{ 'titulo' => 'Plan Empresarial — Precio y…' }] }
    texto = described_class.new(template).text([{ 'role' => 'user', 'content' => '¿precio?' }], traza)

    expect(texto).to include('55 6857 4646', '¿precio?', '$3,221')
    expect(KnowledgeBase::DataGuard.invented('Cuesta $3,221 y hay 52% de descuento', texto)).to eq(['52%'])
  end
end
