# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::TrainingSectionCatalog do
  let(:account) { create(:account) }

  def agente(name, texto)
    create(:tracking_template, account: account, name: name, complementary_prompt: texto)
  end

  def catalogo
    described_class.new(account).call
  end

  it 'trae cada sección con su contenido, su largo y en qué agente está' do
    agente('Licencias', "[ROL]\nSos un asesor de licencias.\nHablás claro.")

    expect(catalogo).to eq([{ title: 'ROL', body: "Sos un asesor de licencias.\nHablás claro.",
                              style: 'bracket', lines: 2, agents: ['Licencias'] }])
  end

  it 'junta las secciones idénticas y nombra los agentes' do
    dos = "[ETIQUETAS]\nCerrá cada turno con una sola etiqueta."
    agente('Uno', dos)
    agente('Dos', dos)

    expect(catalogo.size).to eq(1)
    expect(catalogo.first[:agents]).to contain_exactly('Uno', 'Dos')
  end

  # Lo que se quiere comparar: el mismo nombre escrito de varias maneras.
  it 'separa el mismo nombre con contenidos distintos' do
    agente('Uno', "[ROL]\nSos formal.")
    agente('Dos', "[ROL]\nSos cercano.")

    expect(catalogo.pluck(:body)).to contain_exactly('Sos formal.', 'Sos cercano.')
  end

  it 'ordena por nombre y deja primero la versión más larga' do
    agente('Uno', "[ESTILO]\nBreve.\n\n[ALCANCE POR RAMA]\nsoporte: fallas.")
    agente('Dos', "[ESTILO]\nBreve y claro.\nSin tecnicismos.")

    expect(catalogo.map { |e| [e[:title], e[:lines]] })
      .to eq([['ALCANCE POR RAMA', 1], ['ESTILO', 2], ['ESTILO', 1]])
  end

  it 'no trae las ramas, el texto inicial ni las secciones vacías' do
    agente('Uno', "AGENTE v1\n\n@ruta(soporte #tracking: no abre): -\n\n[VACIA]\n\n[ROL]\nSos amable.")

    expect(catalogo.pluck(:title)).to eq(['ROL'])
  end

  it 'no mira los agentes de otra cuenta' do
    create(:tracking_template, account: create(:account), complementary_prompt: "[ROL]\nAjeno.")

    expect(catalogo).to be_empty
  end

  it 'recorta un contenido desmedido' do
    agente('Uno', "[ROL]\n#{'x' * (described_class::MAX_BODY_CHARS + 100)}")

    expect(catalogo.first[:body].length).to eq(described_class::MAX_BODY_CHARS)
  end
end
