# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — ningún monto, porcentaje ni código que el modelo no vio.
RSpec.describe KnowledgeBase::DataGuard do
  let(:fuente) do
    "Plan Empresarial — Precio y promociones\nPrecio normal: $3,221.00 al mes.\n" \
      "Primera promoción: 38% de descuento, paga $1,990.00, cupón l0601202611.\nPágina: https://ejemplo.com/planes/pe2026"
  end

  it 'deja pasar lo que está en la fuente, escrito de otra forma' do
    respuesta = 'Con la promoción del 38 % paga $1990 al mes (cupón L0601202611).'
    expect(described_class.invented(respuesta, fuente)).to eq([])
  end

  it 'encuentra la promoción inventada: porcentaje, monto y cupón' do
    respuesta = 'Tenemos un 52% de descuento: queda en $1,546.00 con el cupón CE5223.'
    expect(described_class.invented(respuesta, fuente)).to contain_exactly('52%', '$1,546.00', 'CE5223')
  end

  it 'un monto calculado tampoco viene de la fuente' do
    expect(described_class.invented('Por 3 meses serían $5,970.', fuente)).to eq(['$5,970'])
  end

  it 'un monto sin «$» en la fuente cuenta como visto' do
    expect(described_class.invented('Cuesta $450.', 'Costo de envío: 450 pesos')).to eq([])
  end

  it 'no confunde ligas, teléfonos ni horarios con datos inventados' do
    respuesta = 'Llámenos al 55 6857 4646 de 9 a 18 h o entre a https://otra.com/x9y8z7w6.'
    expect(described_class.invented(respuesta, fuente)).to eq([])
  end

  it 'quita solo las oraciones que traen el dato inventado' do
    respuesta = "Claro que sí. Tenemos 52% de descuento. ¿Le interesa?\nSaludos."
    expect(described_class.strip(respuesta, ['52%'])).to eq("Claro que sí. ¿Le interesa?\nSaludos.")
  end
end
