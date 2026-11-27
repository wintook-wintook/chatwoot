# frozen_string_literal: true

require 'rails_helper'

# «Análisis de conversaciones»: los números de conversación se aceptan como vengan de la
# IA (101, "101", "#101") y la muestra es de 100 por omisión, de 10 a 150.
RSpec.describe Cases::Ai::ConversationAnalyst do
  let(:account) { create(:account) }
  let(:analyst) { described_class.new(account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:conversations) do
    Array.new(3) { create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account)) }
  end

  it 'acepta los números de conversación como texto y descarta los que no están en la muestra' do
    ids = conversations.map(&:display_id)
    allow(analyst).to receive(:chat).and_return(
      'topics' => [{ 'label' => 'Precios', 'count' => 2, 'examples' => ["##{ids[0]}", ids[1].to_s, '#99999'] }],
      'upset' => [{ 'conversation' => "##{ids[2]}", 'why' => 'molesto' }],
      'lost_sales' => [{ 'conversation_id' => "conversación #{ids[1]}", 'why' => 'preguntó precio' }],
      'complaints' => []
    )

    result = analyst.analyze
    expect(result['topics'].first['examples']).to eq([ids[0], ids[1]])
    expect(result['upset']).to eq([{ 'conversation' => ids[2], 'why' => 'molesto' }])
    expect(result['lost_sales'].first['conversation']).to eq(ids[1])
    expect(result['sample_size']).to eq(3)
  end

  it 'la muestra va de 10 a 150 y es 100 por omisión' do
    allow(analyst).to receive(:sample_conversations).and_return([])
    analyst.analyze
    analyst.analyze(limit: 500)
    analyst.analyze(limit: '3')
    expect(analyst).to have_received(:sample_conversations).with(nil, 100).ordered
    expect(analyst).to have_received(:sample_conversations).with(nil, 150).ordered
    expect(analyst).to have_received(:sample_conversations).with(nil, 10).ordered
  end
end
