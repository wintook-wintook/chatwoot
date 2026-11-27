# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::SheetSynonyms do
  let(:prompt) do
    <<~PROMPT
      [ROL]
      Vendo autos.

      [SINÓNIMOS]
      PICK UP = picop, pik up, troca, camioneta de carga
      SUV = camioneta suv

      [ESTILO]
      Corto.
    PROMPT
  end

  it 'lee la sección [SINÓNIMOS] y nada más' do
    expect(described_class.parse(prompt)).to eq('PICK UP' => ['picop', 'pik up', 'troca', 'camioneta de carga'],
                                                'SUV' => ['camioneta suv'])
    expect(described_class.parse('[ROL] sin sección')).to eq({})
  end

  it 'agrega el valor cuando el texto nombra un sinónimo o un plural declarado' do
    mapa = described_class.parse(prompt)
    expect(described_class.expand('¿tienen picop?', mapa)).to eq('¿tienen picop? PICK UP')
    expect(described_class.expand('busco pickups', mapa)).to eq('busco pickups PICK UP')
    expect(described_class.expand('¿hay suvs?', mapa)).to eq('¿hay suvs? SUV')
    expect(described_class.expand('un sedán', mapa)).to eq('un sedán')
  end
end
