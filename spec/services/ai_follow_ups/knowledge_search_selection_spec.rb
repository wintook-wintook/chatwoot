# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — el 2.0 y Seguimiento IA buscan con la selección cuando la
# plática la fuerza, y dejan lo que escogieron para la traza del probador.
RSpec.describe AiFollowUps::KnowledgeSearch do
  let(:account) { create(:account) }
  let(:source) { create(:knowledge_source, account: account) }
  let!(:canned) { create(:canned_response, account: account, short_code: 'Horario', content: 'De 9 a 18 h.') }
  let(:item) { create(:knowledge_item, account: account, knowledge_source: source, source_id: canned.id, title: 'Horario') }
  let(:conversation) { Conversation.new(additional_attributes: { 'agent_tester_seleccion' => 'on' }) }

  before do
    candidate = KnowledgeBase::Candidates::Candidate.new(item: item, via: ['palabras'], similarity: nil, words: 2)
    allow(KnowledgeBase::Candidates).to receive(:new).and_return(instance_double(KnowledgeBase::Candidates, call: [candidate]))
    allow(KnowledgeBase::Selector).to receive(:new)
      .and_return(instance_double(KnowledgeBase::Selector, call: { chosen: [candidate], reasons: {}, none: false, missing: '' }))
  end

  it 'con la plática forzada usa la selección y la deja para la traza' do
    search = described_class.new(account: account, conversation: conversation)
    expect(search.canned('¿abren el domingo?')[:results].first).to include(codigo: 'Horario', clase: 'general')
    expect(search.last_selection).to include(candidatas: 1, escogidas: ['Horario'], ninguna: false)
  end

  it 'sin forzarla ni prenderla en la cuenta, la búsqueda de siempre' do
    search = described_class.new(account: account)
    search.canned('horario')
    expect(KnowledgeBase::Selector).not_to have_received(:new)
    expect(search.last_selection).to be_nil
  end
end
