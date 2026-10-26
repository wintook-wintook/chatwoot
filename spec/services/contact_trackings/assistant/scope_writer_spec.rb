# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — la línea de alcance de una ruta, desde sus frases
RSpec.describe ContactTrackings::Assistant::ScopeWriter do
  let(:account) { create(:account) }

  before { account.hooks.create!(app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' }) }

  def responde(texto)
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: { alcance: texto }.to_json } }] }.to_json
    )
  end

  def escribir(ruta)
    described_class.new(account, route: ruta).call
  end

  it 'devuelve la línea para [ALCANCE POR RAMA]' do
    responde('responde precios de las carreras con el catálogo')

    expect(escribir(name: 'precios', phrases: 'cuánto cuesta', source: '{{hoja:CATALOGO}}'))
      .to eq(scope: 'responde precios de las carreras con el catálogo')
  end

  # 25/09/2026: a una ruta sin fuente le puso «con las respuestas predefinidas».
  it 'si la ruta no consulta nada, quita la fuente que el modelo inventó' do
    responde('saluda cordialmente utilizando las respuestas predefinidas')

    expect(escribir(name: 'saludo', phrases: 'hola, buenos días')).to eq(scope: 'saluda cordialmente')
  end

  it 'sin frases no llama a nadie' do
    expect(escribir(name: 'x', phrases: '  ')).to eq(error: :blank_phrases)
  end
end
