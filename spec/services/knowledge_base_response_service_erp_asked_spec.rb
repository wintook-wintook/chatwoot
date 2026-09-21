# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — F2 en el motor (docs/erp_productos_plan.md §3.2–3.6).
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿tienen laptops hp de menos de 15 mil?')
  end
  let(:prompt) { "Eres el vendedor.\n{{consulta:sae/buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}}" }
  let(:tracking) { create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt) }
  let(:query) { instance_double(ExternalDbQuery, name: 'buscar_productos') }
  let(:asked) { instance_double(ExternalDb::AskedConsulta) }
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    allow(ExternalDb::AskedConsulta).to receive(:new).and_return(asked)
    stub_request(:post, chat_url)
      .to_return(status: 200, body: { choices: [{ message: { content: 'Tenemos la HP 240 G9 en $13,499.' } }] }.to_json)
  end

  def sent_prompt
    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    body['messages']
  end

  def last_reply
    conversation.messages.where(message_type: :outgoing).last&.content
  end

  it 'con "?": el agente redacta con los datos exactos y la regla de fidelidad' do
    allow(asked).to receive(:call).and_return(
      query: query, columns: %w[CODIGO NOMBRE PRECIO EXISTENCIA],
      rows: [{ 'CODIGO' => 'LAP-HP-240', 'NOMBRE' => 'HP 240 G9', 'PRECIO' => 13_499.0, 'EXISTENCIA' => 4.0 }]
    )

    expect(described_class.new(message, tracking: tracking).perform).to be(true)
    expect(last_reply).to eq('Tenemos la HP 240 G9 en $13,499.')
    user = sent_prompt.last['content']
    expect(user).to include('CODIGO: LAP-HP-240 · NOMBRE: HP 240 G9 · PRECIO: 13499.00 · EXISTENCIA: 4.00',
                            'DATOS EXACTOS')
    expect(sent_prompt.first['content']).not_to include('{{consulta')
    expect(conversation.reload.additional_attributes['kb_history'].last['a']).to eq(last_reply)
  end

  it 'sin resultados, se lo dice al modelo en vez de dejarlo inventar' do
    allow(asked).to receive(:call).and_return(query: query, columns: [], rows: [])

    described_class.new(message, tracking: tracking).perform
    expect(sent_prompt.last['content']).to include('La consulta no encontró resultados.')
  end

  it 'una coincidencia parcial se le avisa al modelo' do
    allow(asked).to receive(:call).and_return(query: query, columns: ['NOMBRE'], rows: [{ 'NOMBRE' => 'Toshiba' }],
                                              partial: true)

    described_class.new(message, tracking: tracking).perform
    expect(sent_prompt.last['content']).to include('COINCIDENCIA PARCIAL', '1. NOMBRE: Toshiba')
  end

  it 'si no aplica (el mensaje no la pide), no responde: el motor sigue su camino' do
    allow(asked).to receive(:call).and_return(nil)

    expect(described_class.new(message, tracking: tracking).perform).to be(false)
    expect(last_reply).to be_nil
  end

  context 'without "?" (la cobranza de siempre)' do
    let(:prompt) { 'Tu saldo es {{consulta:sae/saldo_cliente}}' }

    it 'interpola y manda el texto sin IA, como siempre' do
      renderer = instance_double(ExternalDb::ConsultaDirectiveRenderer, render: 'Tu saldo es 3480.00')
      allow(ExternalDb::ConsultaDirectiveRenderer).to receive(:new).and_return(renderer)

      expect(described_class.new(message, tracking: tracking).perform).to be(true)
      expect(last_reply).to eq('Tu saldo es 3480.00')
      expect(ExternalDb::AskedConsulta).not_to have_received(:new)
      expect(a_request(:post, chat_url)).not_to have_been_made
    end
  end

  # §3.6: antes se renderizaba el Entrenamiento entero y el cliente recibía el prompt.
  context 'with the consulta as the source of a route' do
    let(:prompt) do
      "@ruta(saldo #cobranza: cuánto debo, mi saldo): {{consulta:sae/saldo_cliente}}\nEres el cobrador. Sé amable."
    end

    it 'usa solo la directiva de la ruta del turno' do
      route = ContactTrackings::RouteMap.parse(prompt).routes.first
      renderer = instance_double(ExternalDb::ConsultaDirectiveRenderer)
      allow(ExternalDb::ConsultaDirectiveRenderer).to receive(:new).and_return(renderer)
      allow(renderer).to receive(:render) { |text| text.sub('{{consulta:sae/saldo_cliente}}', '3480.00') }

      described_class.new(message, tracking: tracking, branch: route).perform

      expect(renderer).to have_received(:render).with('{{consulta:sae/saldo_cliente}}')
      expect(last_reply).to eq('3480.00')
    end
  end
end
