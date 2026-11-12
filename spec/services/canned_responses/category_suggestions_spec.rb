# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R3 (D3) — sugerir categorías por el principio del nombre.
RSpec.describe CannedResponses::CategorySuggestions do
  let(:account) { create(:account) }

  before do
    ['PATITAS HORARIO', 'patitas_precio', 'PATITAS-VACUNAS', '01.VENTAS precios', '01.VENTAS planes',
     'La factura no sale', 'La nube', 'SOLO una', 'Cómo timbrar', 'Cómo cancelar'].each do |nombre|
      create(:canned_response, account: account, short_code: nombre)
    end
  end

  it 'propone los principios repetidos, sin palabras comunes ni las que ya son categoría' do
    sugerencias = described_class.new(account).call

    expect(sugerencias.map { |s| [s[:name], s[:count]] }).to eq([['PATITAS', 3], ['01.VENTAS', 2]])
    expect(sugerencias.first[:canned_ids].size).to eq(3)

    CannedResponseCategory.create!(account: account, name: 'patitas')
    expect(described_class.new(account).call.pluck(:name)).to eq(['01.VENTAS'])
  end

  it 'primero las que ya buscan los agentes' do
    create(:tracking_template, account: account, complementary_prompt: '@ruta(x: y): @buscar_predefinidas(01.VENTAS)')

    expect(described_class.new(account).call.first).to include(name: '01.VENTAS', agents: 1)
  end
end
