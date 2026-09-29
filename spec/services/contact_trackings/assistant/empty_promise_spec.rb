# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::EmptyPromise do
  let(:vacia) { { 'mensaje' => 'Voy a agregar la ruta para varios servicios.', 'entrenamiento' => nil } }

  it 'sin pregunta y sin Entrenamiento, al editar, le da una vuelta más' do
    extra = nil
    nueva = { 'mensaje' => 'Listo.', 'entrenamiento' => '@ruta_por_defecto: x' }
    salida = described_class.second_try(vacia, said: 'que reciba varios servicios', editing: true) do |mas|
      extra = mas
      nueva
    end

    expect(salida['entrenamiento']).to eq('@ruta_por_defecto: x')
    expect(extra.last[:content]).to include('entrenamiento')
  end

  it 'si preguntó, no la repite' do
    pregunta = vacia.merge('mensaje' => '¿Qué frases usan tus clientes?')

    expect { |b| described_class.second_try(pregunta, said: 'x', editing: true, &b) }.not_to yield_control
  end

  it 'un pedido de análisis contesta sin entregar a propósito' do
    expect { |b| described_class.second_try(vacia, said: 'analiza el agente', editing: true, &b) }.not_to yield_control
  end

  it 'al armar desde cero no interviene' do
    expect { |b| described_class.second_try(vacia, said: 'x', editing: false, &b) }.not_to yield_control
  end

  it 'si la segunda vuelta falla, sigue con la primera' do
    expect(described_class.second_try(vacia, said: 'x', editing: true) { nil }).to eq(vacia)
  end
end
