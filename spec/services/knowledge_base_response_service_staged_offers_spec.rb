# frozen_string_literal: true

require 'rails_helper'

# El contexto que arma KBase con la ficha de una carrera solo trae la beca que toca según
# SIGUIENTE_OFERTA (ver KnowledgeBase::StagedOffers).
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, content: 'y no hay otra beca más?')
  end
  let(:prompt) do
    "Agente.\n\n[VARIABLES]\nSIGUIENTE_OFERTA = PRIMERA_BECA | SEGUNDA_BECA | AGOTADA\nInicial: SIGUIENTE_OFERTA=PRIMERA_BECA\n"
  end
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation,
                              complementary_prompt: prompt)
  end
  let(:item) do
    Struct.new(:title, :content).new('Licenciatura en Trabajo Social',
                                     "- Precio normal por materia: $3,221.00\n- Primera beca: 38%\n{{tsbeca1mat}}\n" \
                                     "- Segunda beca: 52%\n{{tsbeca2mat}}\n")
  end

  def contexto
    described_class.new(message, tracking: tracking, branch: nil).send(:items_context, [item], message.content)
  end

  it 'sin variables guardadas usa el valor inicial y oculta la segunda beca' do
    expect(contexto).to include('Primera beca')
    expect(contexto).not_to include('Segunda beca')
  end

  it 'con SIGUIENTE_OFERTA=SEGUNDA_BECA guardada, la muestra' do
    key = ContactTrackings::ConversationVariables.store_key(tracking)
    conversation.update!(additional_attributes: { 'agent_variables' => { key => { 'SIGUIENTE_OFERTA' => 'SEGUNDA_BECA' } } })

    expect(contexto).to include('Primera beca', 'Segunda beca')
  end
end
