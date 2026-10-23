# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Optimizer do
  let(:account) { create(:account) }
  let(:draft) do
    <<~T.strip
      @ruta(soporte #soporte1: no puedo entrar, me da error): -

      [ESTILO]
      Escribe breve. Se breve. No seas extenso en tus respuestas al cliente.

      [NO SIMULAR]
      Nunca digas que ya quedo agendado si el motor no lo confirmo.
    T
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def modelo_propone(entrenamiento, hallazgos: [])
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: { hallazgos: hallazgos, resumen: 'Menos repetición',
                                                entrenamiento: entrenamiento }.to_json } }] }.to_json
    )
  end

  def optimizar
    described_class.new(account, draft: draft).call
  end

  it 'devuelve los hallazgos válidos y la propuesta con sus números' do
    propuesta = draft.sub('Escribe breve. Se breve. No seas extenso en tus respuestas al cliente.', 'Escribe breve.')
    modelo_propone(propuesta, hallazgos: [{ tipo: 'redundante', donde: '[ESTILO]', detalle: 'tres veces lo mismo' },
                                          { tipo: 'inventado', donde: 'x', detalle: 'y' }])

    resultado = optimizar

    expect(resultado[:findings]).to eq([{ kind: 'redundante', where: '[ESTILO]', detail: 'tres veces lo mismo' }])
    expect(resultado[:proposed_draft]).to eq(propuesta)
    expect(resultado[:stats][:chars_after]).to be < resultado[:stats][:chars_before]
  end

  # Optimizar es redacción, no comportamiento: el ruteo no se toca.
  it 'devuelve a como estaban las líneas @ruta que la propuesta cambió' do
    modelo_propone(draft.sub('no puedo entrar, me da error', 'problemas').sub('Se breve. ', ''))

    resultado = optimizar

    expect(resultado[:proposed_draft]).to include('no puedo entrar, me da error')
    expect(resultado[:proposed_draft]).not_to include('Se breve.')
    expect(resultado[:restored]).to eq(['@ruta(soporte)'])
  end

  it 'devuelve una sección que la propuesta borró' do
    modelo_propone(draft.sub("\n\n[NO SIMULAR]\nNunca digas que ya quedo agendado si el motor no lo confirmo.", ''))

    resultado = optimizar

    expect(resultado[:proposed_draft]).to include('[NO SIMULAR]')
    expect(resultado[:restored]).to eq(['[NO SIMULAR]'])
  end

  # Medido sobre el v6.11: borró prohibiciones llamándolas redundantes.
  it 'informa las reglas perdidas y ofrece la versión que no pierde ninguna' do
    propuesta = draft.sub('Se breve. ', '')
                     .sub('Nunca digas que ya quedo agendado si el motor no lo confirmo.', 'Se claro.')
    modelo_propone(propuesta)

    resultado = optimizar

    expect(resultado[:lost_rules].pluck(:section)).to eq(['[NO SIMULAR]'])
    expect(resultado[:safe_draft]).to include('Nunca digas que ya quedo agendado')
    expect(resultado[:safe_draft]).not_to include('Se breve.')
  end

  it 'descarta la propuesta si queda con más bloqueantes' do
    modelo_propone("#{draft}\n\n[PENDIENTE]\n<PENDIENTE: algo>")

    expect(optimizar).to include(proposed_draft: nil, discarded: :worse)
  end

  it 'no propone nada si el modelo devuelve el mismo texto' do
    modelo_propone(draft)

    expect(optimizar).to include(proposed_draft: nil, discarded: :empty)
  end
end
