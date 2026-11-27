# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::ContextLine do
  let(:largo) do
    "Tenemos disponible un Volkswagen Jetta 2019 con transmisión automática en color gris plata. El precio de contado es de $278,800.00.\n\n" \
      "¿Te gustaría verlo físicamente?\n\n#inventario\n\n_INVENTARIO_"
  end

  it 'un mensaje largo conserva su última pregunta y cabe en el límite' do
    corto = described_class.brief(largo)
    expect(corto).to end_with('¿Te gustaría verlo físicamente?')
    expect(corto).to start_with('Tenemos disponible un Volkswagen')
    expect(corto.size).to be <= 121
  end

  it 'quita el pie: etiquetas, fuente y firma' do
    expect(described_class.brief("¡Gracias!\n\n#asesor_ventas\n\n-TB")).to eq('¡Gracias!')
  end

  it 'un mensaje corto o sin pregunta queda como antes' do
    expect(described_class.brief('Me interesa el Jetta')).to eq('Me interesa el Jetta')
    expect(described_class.brief('a' * 200)).to eq("#{'a' * 117}...")
  end

  it 'recent?: lo de hace más de 12 horas ya no es de esta plática' do
    ahora = Time.current
    actual = Struct.new(:created_at).new(ahora)
    expect(described_class.recent?(Struct.new(:created_at).new(ahora - 2.hours), actual)).to be(true)
    expect(described_class.recent?(Struct.new(:created_at).new(ahora - 1.day), actual)).to be(false)
  end
end
