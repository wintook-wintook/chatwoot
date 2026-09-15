# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::SuggestedTests do
  let(:account) { create(:account) }
  let(:draft) do
    <<~T
      @ruta(soporte #soporte: no puedo entrar, me da error): @buscar_articulo
      @ruta(precios #precios: cuanto cuesta la licencia): @buscar_predefinidas
    T
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def modelo_escribe(contenido)
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: contenido.to_json } }] }.to_json
    )
  end

  # El veredicto es del clasificador real; acá se fija qué contesta, mensaje por mensaje.
  def clasificador_responde(tabla)
    allow(ContactTrackings::BranchClassifierService).to receive(:new) do |_t, message, map|
      instance_double(ContactTrackings::BranchClassifierService, classify: map[tabla[message.content]])
    end
  end

  def probar(progress: nil)
    described_class.new(account, draft: draft, progress: progress).call
  end

  it 'da veredicto a los mensajes de cada rama y deja sin veredicto los casos límite' do
    modelo_escribe(ramas: [{ rama: 'soporte', mensajes: ['no me deja entrar'] },
                           { rama: 'precios', mensajes: ['cuanto sale'] }],
                   limites: [{ mensaje: 'hola', rama: nil, por_que: 'saludo' }])
    clasificador_responde('no me deja entrar' => 'soporte', 'cuanto sale' => 'soporte', 'hola' => 'precios')

    casos = probar[:cases]

    expect(casos.map { |c| c.slice(:message, :expected, :chosen, :pass, :kind) }).to eq([
                                                                                          { message: 'no me deja entrar', expected: 'soporte',
                                                                                            chosen: 'soporte', pass: true, kind: :route },
                                                                                          { message: 'cuanto sale', expected: 'precios',
                                                                                            chosen: 'soporte', pass: false, kind: :route },
                                                                                          { message: 'hola', expected: nil, chosen: 'precios',
                                                                                            pass: nil, kind: :edge }
                                                                                        ])
    expect(casos.first).to include(source: '@buscar_articulo', tag: '#soporte')
  end

  # Lo que escribe el modelo se lee con desconfianza: ramas inventadas y mensajes de más.
  it 'descarta ramas que no existen y recorta la cantidad de mensajes' do
    modelo_escribe(ramas: [{ rama: 'inventada', mensajes: ['x'] },
                           { rama: 'soporte', mensajes: %w[uno dos tres cuatro] }],
                   limites: [{ mensaje: 'y', rama: 'otra_inventada' }])
    clasificador_responde({})

    casos = probar[:cases]

    expect(casos.count { |c| c[:kind] == :route }).to eq(described_class::PER_ROUTE)
    expect(casos.find { |c| c[:kind] == :edge }[:expected]).to be_nil
  end

  it 'si el modelo no contesta, prueba con las frases de las descripciones' do
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(status: 500, body: 'boom')
    clasificador_responde('no puedo entrar' => 'soporte', 'me da error' => 'soporte',
                          'cuanto cuesta la licencia' => 'precios')

    resultado = probar

    expect(resultado[:generated_by]).to eq(:descriptions)
    expect(resultado[:cases].pluck(:message)).to eq(['no puedo entrar', 'me da error', 'cuanto cuesta la licencia'])
    expect(resultado[:cases].pluck(:pass)).to eq([true, true, true])
  end

  it 'avisa el avance de a un mensaje' do
    modelo_escribe(ramas: [{ rama: 'soporte', mensajes: %w[a b] }], limites: [])
    clasificador_responde({})
    avances = []

    probar(progress: ->(etapa, **info) { avances << [etapa, info] })

    expect(avances).to eq([[:testing, { done: 0, total: 2 }], [:testing, { done: 1, total: 2 }]])
  end

  it 'no hace nada con un Entrenamiento sin ramas' do
    expect(described_class.new(account, draft: '[ROL] Amable.').call).to eq(cases: [], generated_by: nil)
  end
end
