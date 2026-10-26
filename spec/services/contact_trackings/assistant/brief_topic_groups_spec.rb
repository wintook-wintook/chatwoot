# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::BriefTopicGroups do
  let(:account) { create(:account) }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_usage: { 'prompt_tokens' => 5 }) }

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  def temas(cuantos)
    Array.new(cuantos) { |i| { 'nombre' => "tema #{i + 1}", 'frases_cliente' => ["frase #{i + 1}"], 'origen' => [i] } }
  end

  it 'con pocos temas no hace nada' do
    ficha = { 'temas' => temas(5) }

    expect(described_class.new(account, ficha: ficha).call[:ficha]).to eq(ficha)
  end

  it 'agrupa por intención del cliente, pasa lo interno a «qué hace» y no pierde ningún tema' do
    lista = temas(25)
    lista[0]['fuente'] = '@buscar_foro(Foro)'
    allow(chat).to receive(:call).and_return(
      { 'grupos' => [
        { 'nombre' => 'desarrollo_web', 'frases' => ['quiero una página'], 'que_hace' => 'Diagnostica antes de proponer',
          'temas' => [1, 2, 3], 'internos' => [4] },
        { 'nombre' => 'precios', 'frases' => [], 'temas' => (5..24).to_a + [1] } # el 1 ya se usó: se ignora
      ] }
    )

    r = described_class.new(account, ficha: { 'temas' => lista }).call
    web = r[:ficha]['temas'].first

    expect(web).to include('nombre' => 'desarrollo_web', 'fuente' => '@buscar_foro(Foro)',
                           'junta' => ['tema 1', 'tema 2', 'tema 3', 'tema 4'], 'origen' => [0, 1, 2, 3])
    expect(web['que_hace']).to eq('Diagnostica antes de proponer · tema 4')
    expect(r[:ficha]['temas'].second['frases_cliente']).to eq(['frase 5', 'frase 6', 'frase 7', 'frase 8', 'frase 9', 'frase 10'])
    expect(r[:ficha]['temas'].last['nombre']).to eq('tema 25') # la IA lo olvidó: vuelve suelto
    expect(r[:antes]).to eq(25)
    expect(r[:despues]).to eq(3)
  end

  it 'si la IA no contesta, la ficha queda como estaba' do
    allow(chat).to receive(:call).and_return(nil)
    ficha = { 'temas' => temas(25) }

    expect(described_class.new(account, ficha: ficha).call[:ficha]).to eq(ficha)
  end
end
