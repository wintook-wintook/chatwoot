# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando — los datos fijos de un prompt publicado, en «Configurar».
RSpec.describe ContactTrackings::Assistant::ConstantAdaptation do
  let(:account) { create(:account) }
  let(:texto) do
    "[DATOS FIJOS]\nEMPRESA = Kontrolya\nQ1 (pregunta) = ¿Qué sistema usas? → guarda en SISTEMA\n" \
      "CIERRE = Gracias.\n\n  Agenda en %LIGA%\nLIGA (liga) = https://k.mx\n\n[ROL]\nTrabajas en %EMPRESA%. Hablas de %EMPRESA%."
  end

  it 'cada dato fijo sale como dato del negocio con su valor actual' do
    items = described_class.items(texto)

    expect(items.first).to include(key: 'const:empresa', kind: 'constant', name: 'EMPRESA', current: 'Kontrolya',
                                   status: 'ok', fix: 'text', group: :business, occurrences: 2, line: 2)
    expect(items.pluck(:name)).to eq(%w[EMPRESA Q1 CIERRE LIGA])
  end

  it 'cambia solo la declaración y conserva tipo y «guarda en»' do
    nuevo = described_class.replace(texto, 'q1', '¿Con qué sistema facturas?')

    expect(nuevo).to include('Q1 (pregunta) = ¿Con qué sistema facturas? → guarda en SISTEMA')
    expect(nuevo.sub('Q1 (pregunta) = ¿Con qué sistema facturas?', 'Q1 (pregunta) = ¿Qué sistema usas?')).to eq(texto)
  end

  it 'un valor de varios renglones reemplaza también su continuación' do
    nuevo = described_class.replace(texto, 'cierre', "Listo.\nTe espero")

    expect(nuevo).to include("CIERRE = Listo.\n  Te espero\nLIGA (liga) = https://k.mx")
    expect(nuevo).not_to include('Agenda en')
  end

  it 'un nombre que no está deja el texto igual' do
    expect(described_class.replace(texto, 'otro', 'x')).to eq(texto)
  end

  it 'entra a «Configurar»: el inventario lo lista y el aplicador lo escribe' do
    items = ContactTrackings::Assistant::AdaptationInventory.new(texto, account: account).call
    expect(items.find { |i| i[:key] == 'const:empresa' }).to include(current: 'Kontrolya')

    resultado = ContactTrackings::Assistant::AdaptationApplier.new(texto, { 'const:empresa' => 'Grúas del Sur' }).call
    expect(resultado.applied).to eq(['const:empresa'])
    expect(ContactTrackings::PromptConstants.expand(resultado.text)).to include('Trabajas en Grúas del Sur. Hablas de Grúas del Sur.')
  end
end
