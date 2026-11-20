require 'rails_helper'

RSpec.describe ContactTrackings::SheetNumbers do
  describe '.in_text' do
    it 'toneladas: acepta t, ton, toneladas y kilos convertidos' do
      expect(described_class.in_text('grúa de 80 toneladas para una carga de 26 t', 'capacidad_t')).to eq([80.0, 26.0])
      expect(described_class.in_text('peso total estimado: 8,800 kg', 'peso_max_t')).to eq([8.8])
    end

    it 'no confunde fechas ni horas con toneladas' do
      expect(described_class.in_text('el lunes 28 a las 10:00, 3 tramos', 'capacidad_t')).to eq([])
    end

    it 'metros: m, mts, metros' do
      expect(described_class.in_text('plana de 12 mts y torton de 7 m', 'largo_m')).to eq([12.0, 7.0])
    end

    it 'otra columna: el número que va con la palabra de la columna' do
      expect(described_class.in_text('hiab 12 ton con 5 extensiones', 'extensiones')).to eq([5.0])
    end
  end

  describe '.cell' do
    it 'lee decimales y miles' do
      expect(%w[40.8 1,100 12,5 60].map { |v| described_class.cell(v) }).to eq([40.8, 1100.0, 12.5, 60.0])
      expect(described_class.cell('sin dato')).to be_nil
    end
  end

  describe 'años' do
    it 'lee el año sin unidad en una columna de año' do
      expect(described_class.kind('MODELO')).to eq(:year)
      expect(described_class.in_text('¿Qué tienen del 2020 en adelante?', 'MODELO')).to eq([2020])
      expect(described_class.in_text('más nuevo que 2021', 'año')).to eq([2021])
    end

    it 'no toma precios ni teléfonos por años' do
      expect(described_class.in_text('menos de $200,000 o 2020 mil', 'MODELO')).to eq([])
      expect(described_class.in_text('mi cel 3312020567', 'MODELO')).to eq([])
    end
  end
end
