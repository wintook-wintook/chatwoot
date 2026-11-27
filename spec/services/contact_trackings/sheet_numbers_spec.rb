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

    it 'abreviaturas que también escriben los clientes: tns, tn, mt, mtrs (27/11/2026)' do
      expect(described_class.in_text('una carga de 20 tns y otra de 3 tn', 'peso_max_t')).to eq([20.0, 3.0])
      expect(described_class.in_text('mide 9 mtrs, la otra 4 mt', 'largo_m')).to eq([9.0, 4.0])
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

  describe ContactTrackings::SheetRanges do
    it 'lee rangos de dinero; el primero toma la unidad del segundo' do
      expect(described_class.in_text('¿algo entre 100 mil y 200 mil?', 'PRECIO')).to eq([100_000.0, 200_000.0])
      expect(described_class.in_text('de 150 a 250 mil', 'PRECIO')).to eq([150_000.0, 250_000.0])
      expect(described_class.in_text('desde $120,000 hasta $180,000', 'PRECIO')).to eq([120_000.0, 180_000.0])
    end

    it 'un tope solo, un año o toneladas no son rango de dinero' do
      expect(described_class.in_text('menos de 200 mil', 'PRECIO')).to be_nil
      expect(described_class.in_text('de 200 mil y 2020', 'PRECIO')).to be_nil
      expect(described_class.in_text('grúa entre 20 y 30 toneladas', 'capacidad_t')).to be_nil
    end

    it 'lee rangos de años' do
      expect(described_class.in_text('entre 2018 y 2020', 'MODELO')).to eq([2018, 2020])
      expect(described_class.in_text('del 2020 en adelante', 'MODELO')).to be_nil
    end
  end
end
