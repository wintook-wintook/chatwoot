# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ProbePhrases do
  def ruta(descripcion)
    ContactTrackings::RouteMap::Route.new(name: 'x', description: descripcion)
  end

  it 'toma cada situación de la descripción' do
    expect(described_class.for(ruta('no puedo entrar, me da error al timbrar'), limit: 2))
      .to eq(['no puedo entrar', 'me da error al timbrar'])
  end

  # "usar" a secas no es un mensaje: medido, el clasificador no elige ninguna rama.
  it 'suma situaciones hasta tener al menos tres palabras' do
    expect(described_class.for(ruta('usar, configurar, dar de alta un cliente')))
      .to eq(['usar, configurar, dar de alta un cliente'])
  end

  it 'entrega la última aunque quede corta' do
    expect(described_class.for(ruta('no puedo entrar, falla'), limit: 2)).to eq(['no puedo entrar', 'falla'])
  end

  it 'no da frases de una descripción pendiente o vacía' do
    expect(described_class.for(ruta('<PENDIENTE: frases del cliente>'))).to eq([])
    expect(described_class.for(ruta(nil))).to eq([])
  end
end
