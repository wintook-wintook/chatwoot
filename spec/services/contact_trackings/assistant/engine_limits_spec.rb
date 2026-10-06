# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::EngineLimits do
  it 'avisa, con las reglas que afecta, lo que el motor hace por su cuenta' do
    ficha = { 'reglas' => [{ 'texto' => 'Trata de usted al prospecto', 'ids' => ['C7-03.05'] },
                           { 'texto' => 'Cierra cada mensaje con una sola pregunta', 'regla_id' => 'C7-01.09' }],
              'prohibiciones' => [{ 'texto' => 'Nunca des precios' }] }

    avisos = described_class.call(ficha)

    expect(avisos.pluck('clave')).to eq(%w[usted cierre_pregunta])
    expect(avisos.first['ejemplos']).to eq(['C7-03.05'])
    expect(avisos.second['ejemplos']).to eq(['C7-01.09'])
  end

  it 'sin reglas que choquen, nada' do
    expect(described_class.call({ 'reglas' => [{ 'texto' => 'Saluda con el nombre' }] })).to be_empty
  end
end
