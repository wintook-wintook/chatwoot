# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Explainer do
  let(:account) { create(:account) }
  let(:draft) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): @buscar_articulo -> @crear_ticket(tipo=Soporte)
      @ruta_por_defecto: soporte

      [MENSAJE CON DOS TEMAS]
      Aunque atiendas dos temas, cierra con UNA SOLA etiqueta.
      Si no sabes, consulta @discourse.
    T
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def modelo_explica
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: { explicacion: 'Evita cerrar con dos etiquetas.', aplica_a: ['soporte'],
                                                si_se_quita: 'Podría cerrar con dos.' }.to_json } }] }.to_json
    )
  end

  def explicar(fragmento)
    described_class.new(account, draft: draft, excerpt: fragmento).call
  end

  # Lo que lee el motor sale del parser, no del modelo.
  it 'describe lo que el motor lee de las líneas de ruteo del fragmento' do
    modelo_explica

    motor = explicar(draft.lines.first(2).join)[:engine]

    expect(motor[:routes]).to eq([{ name: 'soporte', tag: '#soporte1', description: 'no puedo entrar',
                                    source: '@buscar_articulo', source_mode: :article,
                                    escalation: '@crear_ticket(tipo=Soporte)' }])
    expect(motor[:default_route]).to eq('soporte')
  end

  it 'avisa la directiva escrita en la prosa, que desde ahí no se ejecuta' do
    modelo_explica

    expect(explicar('Si no sabes, consulta @discourse.')[:engine][:loose_directives]).to eq(['@discourse'])
  end

  it 'ubica la sección del fragmento y trae la lectura del modelo aparte' do
    modelo_explica

    resultado = explicar('Aunque atiendas dos temas, cierra con UNA SOLA etiqueta.')

    expect(resultado[:section]).to eq('[MENSAJE CON DOS TEMAS]')
    expect(resultado[:engine][:routes]).to be_empty
    expect(resultado[:interpretation]).to eq(explanation: 'Evita cerrar con dos etiquetas.', applies_to: ['soporte'],
                                             if_removed: 'Podría cerrar con dos.')
  end

  # Sin modelo, lo del motor sigue valiendo.
  it 'devuelve lo del motor aunque el modelo no conteste' do
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(status: 500, body: 'x')

    resultado = explicar(draft.lines.first)

    expect(resultado[:engine][:routes].size).to eq(1)
    expect(resultado[:interpretation]).to be_nil
  end

  it 'rechaza un fragmento vacío' do
    expect(explicar('  ')).to eq(error: :blank_excerpt)
  end
end
