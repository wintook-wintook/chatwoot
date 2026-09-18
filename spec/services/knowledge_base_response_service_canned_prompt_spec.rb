# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_prompt — el motor con respuestas predefinidas que traen prompt
# (docs/predefinidas_prompt_plan.md §3.7).
RSpec.describe KnowledgeBaseResponseService do
  let(:account)      { create(:account) }
  let(:inbox)        { create(:inbox, account: account) }
  let(:contact)      { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: 'Cuánto cuesta una laptop?')
  end
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                              complementary_prompt: "Eres el asesor de ventas.\n@buscar_predefinidas")
  end
  let(:source) { create(:knowledge_source, account: account, source_type: 'canned_response') }
  let(:precios) do
    create(:canned_response, account: account, short_code: 'PRECIOS LAPTOP', content: 'Laptop Dell: $15,000.')
  end
  let(:vecina) do
    create(:canned_response, account: account, short_code: 'GARANTIA', content: 'Garantía de un año.')
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: 200, body: { data: [{ embedding: [0.1, 0.2] }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def item_for(canned_response)
    create(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response',
                            source_id: canned_response.id, title: canned_response.short_code,
                            content: "#{canned_response.short_code}: #{canned_response.content}")
  end

  def found(*canned_responses)
    allow(KnowledgeItem).to receive(:search_by_embedding).and_return(canned_responses.map { |c| item_for(c) })
  end

  def stub_chat(*replies)
    stub_request(:post, chat_url).to_return(
      *replies.map { |r| { status: 200, body: { choices: [{ message: { content: r } }] }.to_json } }
    )
  end

  # El mensaje del usuario del n-ésimo pedido a OpenAI (el último de la lista).
  def turn_sent(nth = 0)
    bodies = []
    expect(a_request(:post, chat_url).with { |req| bodies << JSON.parse(req.body) }).to have_been_made.at_least_once
    bodies[nth]['messages'].last['content']
  end

  def perform
    described_class.new(message, tracking: tracking).perform
  end

  def last_reply
    conversation.messages.where(message_type: :outgoing).last&.content
  end

  it 'sin prompt: como siempre, con las respuestas encontradas' do
    found(precios, vecina)
    stub_chat('La laptop Dell cuesta $15,000.')

    expect(perform).to be(true)
    expect(turn_sent).to include('Información relevante:', 'PRECIOS LAPTOP', 'GARANTIA')
    expect(turn_sent).not_to include('INSTRUCCIONES PARA ESTA RESPUESTA')
  end

  it 'con Prompt de Contenido: el mensaje es la información y el prompt dice cómo responder, solo con esa respuesta' do
    precios.update!(content_prompts: 'Da el precio y pregunta cuántas unidades necesita.')
    found(precios, vecina)
    stub_chat('La laptop cuesta $15,000. ¿Cuántas necesitas?')

    expect(perform).to be(true)
    expect(turn_sent).to include('Laptop Dell: $15,000.', 'Da el precio y pregunta cuántas unidades necesita.')
    expect(turn_sent).not_to include('GARANTIA', 'Garantía de un año.')
    expect(last_reply).to start_with('La laptop cuesta $15,000. ¿Cuántas necesitas?')
  end

  it 'el mensaje es el prompt: manda sobre el Prompt de Contenido' do
    precios.update!(content: 'Pide el modelo que busca y di que un asesor le cotiza.',
                    content_is_prompt: true, content_prompts: 'IGNORAME')
    found(precios, vecina)
    stub_chat('¿Qué modelo buscas? Un asesor te cotiza.')

    expect(perform).to be(true)
    expect(turn_sent).to include('Pide el modelo que busca y di que un asesor le cotiza.')
    expect(turn_sent).not_to include('IGNORAME', 'Información de la respuesta', 'GARANTIA')
  end

  it 'el prompt de la segunda no aplica' do
    vecina.update!(content_is_prompt: true)
    found(precios, vecina)
    stub_chat('La laptop Dell cuesta $15,000.')

    perform

    expect(turn_sent).to include('Información relevante:')
    expect(turn_sent).not_to include('INSTRUCCIONES PARA ESTA RESPUESTA')
  end

  it 'la respuesta que copia el prompt se descarta y se responde como siempre' do
    precios.update!(content_prompts: 'Esta es la respuesta que darás si alguien te pregunta por laptops.')
    found(precios, vecina)
    stub_chat('Esta es la respuesta que darás si alguien te pregunta por laptops: $15,000.',
              'La laptop Dell cuesta $15,000.')

    expect(perform).to be(true)
    expect(last_reply).to start_with('La laptop Dell cuesta $15,000.')
    expect(last_reply).not_to include('darás')
    expect(conversation.reload.additional_attributes['kb_history'].pluck('a'))
      .to eq(['La laptop Dell cuesta $15,000.'])
  end
end
