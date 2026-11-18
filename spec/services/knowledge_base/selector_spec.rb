# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — la IA chica escoge hasta 3 que sí contestan, o ninguna.
RSpec.describe KnowledgeBase::Selector do
  let(:account) { create(:account) }
  let(:costos) { candidate('Plan Empresarial — Precio y promociones', "PRECIO\n$3,221 al mes.\nPromoción: 38% de descuento.", 'ficha') }
  let(:tramite) { candidate('Plan Empresarial — Alta y trámites', "ALTA\nEl trámite de alta tiene un descuento del 40%.", 'ficha') }
  let(:objecion) { candidate('ESTÁ MUY CARO', 'Entiendo, comparemos lo que incluye…', 'objecion') }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_usage: { 'prompt_tokens' => 900 }) }
  let(:selector) { described_class.new(account, api_key: 'sk-test') }

  def candidate(title, content, kind = 'general')
    KnowledgeBase::Candidates::Candidate.new(
      item: build(:knowledge_item, id: rand(1..1_000_000), title: title, content: "#{title}: #{content}",
                                   metadata: { 'kind' => kind }),
      via: ['similitud'], similarity: 0.6, words: 0
    )
  end

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  it 'le pasa a la IA tipo, nombre, primera línea y dónde coincidió; devuelve las escogidas en su orden' do
    allow(chat).to receive(:call).and_return('elegidas' => [{ 'n' => 1, 'por_que' => 'trae la promoción' }], 'ninguna' => false)

    result = selector.call(question: '¿hay algún otro descuento?', candidates: [costos, tramite, objecion],
                           subjects: ['Plan Empresarial'], conversation: 'Cliente: me interesa el Plan Empresarial')

    expect(result[:chosen]).to eq([costos])
    expect(result[:reasons][costos.item.id]).to eq('trae la promoción')
    expect(chat).to have_received(:call) do |messages, **opts|
      texto = messages.last[:content]
      expect(texto).to include('1. [ficha] Plan Empresarial — Precio y promociones', 'Sujeto en curso', 'descuento')
      expect(texto).to include('3. [objecion] ESTÁ MUY CARO')
      expect(opts[:model]).to eq(described_class::MODEL)
    end
  end

  it '«ninguna» es una respuesta: no escoge lo más parecido por escoger' do
    allow(chat).to receive(:call).and_return('elegidas' => [], 'ninguna' => true, 'falta' => 'costo de envío')
    result = selector.call(question: '¿cuánto cuesta el envío?', candidates: [costos])
    expect(result).to include(chosen: [], none: true, missing: 'costo de envío')
  end

  it 'ignora números que no existen y no pasa de 3' do
    allow(chat).to receive(:call).and_return('elegidas' => [{ 'n' => 9 }, { 'n' => 2 }, { 'n' => 2 }, { 'n' => 1 }, { 'n' => 3 }])
    result = selector.call(question: 'precio', candidates: [costos, tramite, objecion])
    expect(result[:chosen]).to eq([tramite, costos, objecion])
  end

  it 'si la IA no contesta devuelve nil (quien llama vuelve a la búsqueda de siempre)' do
    allow(chat).to receive(:call).and_return(nil)
    expect(selector.call(question: 'precio', candidates: [costos])).to be_nil
  end

  it 'sin candidatas no llama a la IA' do
    allow(chat).to receive(:call)
    expect(selector.call(question: 'precio', candidates: [])).to include(none: true)
    expect(chat).not_to have_received(:call)
  end

  it 'nunca deja pasar la ficha de otro sujeto mientras hay sujeto en curso, salvo que el cliente lo nombre' do
    otra = candidate('Plan Básico — Precio y promociones', 'Precio $990.', 'ficha')
    allow(chat).to receive(:call).and_return('elegidas' => [{ 'n' => 2 }, { 'n' => 1 }])

    result = selector.call(question: '¿hay descuento?', candidates: [costos, otra], subjects: ['Plan Empresarial'])
    expect(result[:chosen]).to eq([costos])

    nombrado = selector.call(question: '¿y el Plan Básico cuánto cuesta?', candidates: [costos, otra], subjects: ['Plan Empresarial'])
    expect(nombrado[:chosen]).to eq([otra, costos])
  end

  it 'le enseña las secciones de cada candidata' do
    allow(chat).to receive(:call).and_return('elegidas' => [{ 'n' => 1 }])
    ficha = candidate('Plan X', "PLAN X\n\nPRECIO\n$10\n\nINSCRIPCIÓN Y ALTA\nLiga: https://x.com", 'ficha')
    selector.call(question: '¿dónde me inscribo?', candidates: [ficha])
    expect(chat).to have_received(:call) { |messages, **| expect(messages.last[:content]).to include('Secciones: PRECIO · INSCRIPCIÓN Y ALTA') }
  end
end
