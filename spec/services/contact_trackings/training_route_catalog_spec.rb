# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::TrainingRouteCatalog do
  let(:account) { create(:account) }

  def agente(name, texto)
    create(:tracking_template, account: account, name: name, complementary_prompt: texto)
  end

  def catalogo
    described_class.new(account).call
  end

  it 'trae cada rama con sus campos y su línea de alcance' do
    agente('Licencias', <<~T)
      @ruta(comercial #demo: cuanto cuesta, precios): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial, prioridad=alta)

      [ALCANCE POR RAMA]
      comercial: responde precios con la lista vigente.
    T

    expect(catalogo).to eq([{
                             name: 'comercial', tag: 'demo', description: 'cuanto cuesta, precios',
                             source: '{{hoja:Precios}}', escalation: '@crear_ticket(tipo=Comercial, prioridad=alta)',
                             action: '@crear_ticket', case_type: 'Comercial', priority: 'alta',
                             scope: 'responde precios con la lista vigente.', agents: ['Licencias']
                           }])
  end

  # La misma rama escrita igual en dos agentes es UNA entrada que dice en cuáles está.
  it 'junta las ramas idénticas y nombra los agentes que las usan' do
    dos = "@ruta(humano #tracking: quiero hablar con alguien): -\n"
    agente('Soporte', dos)
    agente('Ventas', dos)

    expect(catalogo.size).to eq(1)
    expect(catalogo.first[:agents]).to contain_exactly('Soporte', 'Ventas')
  end

  # Si difieren en la fuente o en las frases, son dos: elegir una u otra no da lo mismo.
  it 'separa dos ramas con el mismo nombre escritas distinto' do
    agente('Uno', '@ruta(soporte #tracking: no puedo entrar): @buscar_articulo')
    agente('Dos', '@ruta(soporte #tracking: no puedo entrar): @discourse')

    expect(catalogo.map { |e| e[:source] }).to contain_exactly('@buscar_articulo', '@discourse')
  end

  it 'ordena alfabéticamente por nombre' do
    agente('Uno', "@ruta(humano #tracking: un asesor): -\n@ruta(comercial #demo: precios): -\n@ruta(admin #demo: facturas): -")

    expect(catalogo.map { |e| e[:name] }).to eq(%w[admin comercial humano])
  end

  it 'no trae la rama por defecto ni la prosa' do
    agente('Uno', "@ruta(soporte #tracking: no abre): -\n@ruta_por_defecto: soporte\n\n[ROL]\nSos amable.")

    expect(catalogo.map { |e| e[:name] }).to eq(['soporte'])
  end

  it 'ignora los agentes sin Entrenamiento' do
    create(:tracking_template, account: account, complementary_prompt: nil)

    expect(catalogo).to be_empty
  end

  it 'no mira los agentes de otra cuenta' do
    otra = create(:account)
    create(:tracking_template, account: otra, complementary_prompt: '@ruta(ajena #x_x: algo): -')

    expect(catalogo).to be_empty
  end
end
