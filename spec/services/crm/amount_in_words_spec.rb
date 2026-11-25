# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q4.0 — importe con letra como `config.numeroALetras` de master2.
RSpec.describe Crm::AmountInWords do
  def words(amount, currency = 'PESOS/M.N.')
    described_class.new(amount, currency).to_s
  end

  it 'arma número, moneda, centavos y sufijo como master2' do
    expect(words(1200.5)).to eq('Un mil doscientos PESOS 50/100 M.N.')
    expect(words(0)).to eq('Cero PESOS 00/100 M.N.')
    expect(words(0.07)).to eq('Cero PESOS 07/100 M.N.')
  end

  it 'unidades, decenas y veintes' do
    expect(words(1, nil)).to eq('Un 00/100')
    expect(words(15, nil)).to eq('Quince 00/100')
    expect(words(16, nil)).to eq('Dieciseis 00/100')
    expect(words(21, nil)).to eq('Veintiun 00/100')
    expect(words(45, nil)).to eq('Cuarenta y cinco 00/100')
  end

  it 'cientos' do
    expect(words(100, nil)).to eq('Cien 00/100')
    expect(words(101, nil)).to eq('Ciento un 00/100')
    expect(words(999, nil)).to eq('Novecientos noventa y nueve 00/100')
  end

  it 'miles y millones (millones cerrados llevan «de»)' do
    expect(words(1000, nil)).to eq('Un mil 00/100')
    expect(words(21_000, nil)).to eq('Veintiun mil 00/100')
    expect(words(1_000_000)).to eq('Un millón de PESOS 00/100 M.N.')
    expect(words(2_500_000, nil)).to eq('Dos millones quinientos mil 00/100')
    expect(words(3_000_000, nil)).to eq('Tres millones de 00/100')
    expect(words(1_234_567.89, nil)).to eq('Un millón doscientos treinta y cuatro mil quinientos sesenta y siete 89/100')
  end

  it 'el texto de la moneda: sin «/» todo va antes de los centavos; sin texto, nada' do
    expect(words(10, 'DÓLARES')).to eq('Diez DÓLARES 00/100')
    expect(words(10, ' DÓLARES / USD ')).to eq('Diez DÓLARES 00/100 USD')
    expect(words(10, '')).to eq('Diez 00/100')
  end

  it 'redondea a centavos' do
    expect(words(10.005, nil)).to eq('Diez 01/100')
  end
end
