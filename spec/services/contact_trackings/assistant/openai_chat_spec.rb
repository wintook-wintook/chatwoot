# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::OpenaiChat do
  let(:account) { create(:account) }
  let(:chat) { described_class.new(account: account) }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def responde(content, finish_reason: 'stop', status: 200)
    stub_request(:post, described_class::API_URL).to_return(
      status: status, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ finish_reason: finish_reason, message: { content: content } }] }.to_json
    )
  end

  it 'devuelve el JSON que contestó el modelo' do
    responde({ mensaje: 'hola' }.to_json)

    expect(chat.call([{ role: 'user', content: 'x' }])).to eq('mensaje' => 'hola')
  end

  # Editar un Entrenamiento grande puede no entrar en el tope de tokens. Llega un JSON
  # a la mitad: tiene que leerse como falla, y el log tiene que decir por qué.
  it 'trata como falla una respuesta cortada por el tope de tokens' do
    responde('{"mensaje": "Listo", "entrenamiento": "@ruta(sop', finish_reason: 'length')
    allow(Rails.logger).to receive(:error)

    expect(chat.call([])).to be_nil
    expect(Rails.logger).to have_received(:error).with(/max_tokens/)
  end

  it 'devuelve nil ante un error HTTP o un contenido que no es JSON' do
    responde('no es json')
    expect(chat.call([])).to be_nil

    responde('{}', status: 500)
    expect(chat.call([])).to be_nil
  end

  # Mismo tope que el resto del motor para el Asistente, que ahora devuelve
  # Entrenamientos enteros al editar.
  it 'pide el tope de tokens del Asistente' do
    responde('{}')

    chat.call([])

    tope = ContactTrackings::EngineConfig.max_tokens_for(:authoring_assistant)
    expect(a_request(:post, described_class::API_URL).with { |req| JSON.parse(req.body)['max_tokens'] == tope })
      .to have_been_made
  end
end
