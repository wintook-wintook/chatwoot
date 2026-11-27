# frozen_string_literal: true

require 'rails_helper'

# 11/11/2026 (cuenta 1128, pilas 261109): «¿En qué enlace me inscribo?» no nombra la
# carrera y la ficha no entraba entre los resultados; la carrera ya estaba en CARRERA.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:prompt) { "Agente.\n\n[VARIABLES]\nCARRERA=VACÍO|valor\nPRECIO_DADO=NO|SI\nInicial: CARRERA=VACÍO; PRECIO_DADO=NO." }
  let(:tracking) { create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt) }

  def queries(pregunta, guardadas = nil)
    conversation.update!(additional_attributes: { 'agent_variables' => { "tracking_#{tracking.id}" => guardadas } }) if guardadas
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, content: pregunta)
    described_class.new(message, tracking: tracking, branch: nil).send(:search_queries, pregunta)
  end

  it 'busca también con la carrera guardada cuando la pregunta no la nombra' do
    resultado = queries('Ya revisé todo y me interesa, ¿en qué enlace me inscribo a la carrera por favor?',
                        { 'CARRERA' => 'Licenciatura en Derecho', 'PRECIO_DADO' => 'SI' })

    expect(resultado.first).to eq('Ya revisé todo y me interesa, ¿en qué enlace me inscribo a la carrera por favor?')
    expect(resultado.second).to eq('Licenciatura en Derecho Ya revisé todo y me interesa, ¿en qué enlace me inscribo a la carrera por favor?')
    expect(resultado.join).not_to include('SI Ya')
  end

  it 'no agrega nada con la variable en su valor declarado (VACÍO)' do
    pregunta = 'Ya revisé todo y me interesa, ¿en qué enlace me inscribo a la carrera por favor?'

    expect(queries(pregunta)).to eq([pregunta])
  end

  it 'no repite la carrera si la pregunta ya la nombra' do
    pregunta = 'Me interesa mucho saber cuál es el enlace para la Licenciatura en Derecho, por favor'

    expect(queries(pregunta, { 'CARRERA' => 'Licenciatura en Derecho' })).to eq([pregunta])
  end
end
