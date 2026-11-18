# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — buscar y escoger en el motor de siempre: las
# escogidas llegan marcadas y con sus reglas; «ninguna» se dice en vez de pasar al
# conversacional; un dato que el modelo no vio no sale.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account, custom_attributes: { 'kbase_search' => { 'seleccion' => true } }) }
  let(:costos) { item('Plan Empresarial — Precio y promociones', 'Precio $3,221. Primera promoción: 38%, paga $1,990.', 'ficha') }
  let(:pagos) { item('Formas de pago', 'Tarjeta, transferencia o depósito.', 'general') }
  let(:otro) { item('Plan Básico — Precio', 'Precio $990.', 'ficha') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Hay algún otro descuento?')
  end
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                              complementary_prompt: "Eres el asesor de ventas.\n@buscar_predefinidas")
  end
  let(:source) { create(:knowledge_source, account: account, source_type: 'canned_response') }
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }
  let(:selector) { instance_double(KnowledgeBase::Selector, last_usage: nil) }

  def item(title, content, kind)
    create(:knowledge_item, account: account, knowledge_source: source, title: title, content: "#{title}: #{content}",
                            metadata: { 'kind' => kind })
  end

  def candidate(knowledge_item, similarity = 0.6)
    KnowledgeBase::Candidates::Candidate.new(item: knowledge_item, via: ['similitud'], similarity: similarity, words: 0)
  end

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: 200, body: { data: [{ embedding: [0.1, 0.2] }] }.to_json, headers: { 'Content-Type' => 'application/json' })
    allow(KnowledgeBase::Selector).to receive(:new).and_return(selector)
  end

  def candidates(*list)
    allow(KnowledgeBase::Candidates).to receive(:new).and_return(instance_double(KnowledgeBase::Candidates, call: list))
  end

  def stub_chat(*replies)
    stub_request(:post, chat_url).to_return(
      *replies.map { |r| { status: 200, body: { choices: [{ message: { content: r } }] }.to_json } }
    )
  end

  def sent(nth = 0)
    bodies = []
    expect(a_request(:post, chat_url).with { |req| bodies << JSON.parse(req.body) }).to have_been_made.at_least_once
    bodies[nth]['messages'].last['content']
  end

  def perform = described_class.new(message, tracking: tracking).perform
  def last_reply = conversation.messages.where(message_type: :outgoing).last&.content

  it 'las escogidas llegan en el orden de la IA, marcadas y con las reglas de uso' do
    candidates(candidate(pagos), candidate(costos), candidate(otro))
    allow(selector).to receive(:call).and_return(chosen: [candidate(costos), candidate(pagos)], reasons: {}, none: false, missing: '')
    stub_chat('Con la primera promoción del 38% paga $1,990.')

    expect(perform).to be(true)
    texto = sent
    expect(texto).to include('CÓMO USAR LA INFORMACIÓN')
    expect(texto).to include('1. [FICHA DE «Plan Empresarial»] Plan Empresarial — Precio y promociones')
    expect(texto).to include('2. [GENERAL] Formas de pago')
    expect(texto).not_to include('Plan Básico')
    expect(last_reply).to include('$1,990')
  end

  it '«ninguna»: el agente lo dice con sus reglas, no pasa al conversacional' do
    candidates(candidate(pagos, 0.5))
    allow(selector).to receive(:call).and_return(chosen: [], reasons: {}, none: true, missing: 'costo de envío')
    stub_chat('Ese dato no lo tengo a la mano; le puedo compartir nuestras formas de pago.')

    expect(perform).to be(true)
    expect(sent).to include('Ninguna respuesta predefinida contesta', 'falta: costo de envío', 'Formas de pago')
  end

  it 'si la IA falla vuelve a la búsqueda de siempre, sin marcas' do
    candidates(candidate(costos))
    allow(selector).to receive(:call).and_return(nil)
    allow(KnowledgeItem).to receive(:search_by_embedding).and_return([costos])
    stub_chat('El plan cuesta $3,221.')

    expect(perform).to be(true)
    expect(sent).not_to include('CÓMO USAR LA INFORMACIÓN')
  end

  it 'un dato que el modelo no vio se pide de nuevo; si sigue, se quita la oración' do
    candidates(candidate(costos))
    allow(selector).to receive(:call).and_return(chosen: [candidate(costos)], reasons: {}, none: false, missing: '')
    stub_chat('Tenemos un 52% de descuento con el cupón CE5223. ¿Le interesa?',
              'Hay un 52% de descuento. Con la primera promoción paga $1,990. ¿Le interesa?')

    expect(perform).to be(true)
    expect(sent(1)).to include('REVISIÓN', '52%', 'CE5223')
    expect(last_reply).to include('$1,990')
    expect(last_reply).not_to include('52%')
  end

  context 'with the selection off' do
    let(:account) { create(:account) }

    it 'no la usa' do
      allow(KnowledgeItem).to receive(:search_by_embedding).and_return([costos])
      stub_chat('El plan cuesta $3,221.')

      expect(perform).to be(true)
      expect(KnowledgeBase::Selector).not_to have_received(:new)
    end
  end
end
