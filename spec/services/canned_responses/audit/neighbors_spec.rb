# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — los pares a comparar salen de los vectores (pgvector).
RSpec.describe CannedResponses::Audit::Neighbors do
  let(:account) { create(:account) }
  let!(:uno) { predefinida('UNO', 0) }
  let!(:casi_uno) { predefinida('CASI_UNO', 10) }   # cos 10° = 0.985
  let!(:pariente) { predefinida('PARIENTE', 40) }   # con UNO: cos 40° = 0.766
  let!(:lejana) { predefinida('LEJANA', 75) } # con UNO: 0.259; con PARIENTE: cos 35° = 0.819

  # Un vector unitario en el plano de las dos primeras dimensiones, a `grados` del eje x:
  # la similitud coseno entre dos es cos(diferencia de ángulos).
  def vector(grados)
    radianes = grados * Math::PI / 180
    [Math.cos(radianes), Math.sin(radianes)] + Array.new(1534, 0.0)
  end

  def predefinida(nombre, grados)
    registro = create(:canned_response, account: account, short_code: nombre)
    create(:knowledge_item, account: account, source_type: 'canned_response', source_id: registro.id,
                            title: nombre, embedding: vector(grados))
    registro
  end

  it 'da cada par una vez, con el id menor primero y de la más parecida a la menos' do
    pares = described_class.new(account).all

    expect(pares.map { |a, b, _| [a, b] }).to eq([[uno.id, casi_uno.id], [casi_uno.id, pariente.id],
                                                  [pariente.id, lejana.id], [uno.id, pariente.id]])
    expect(pares.first.last).to be_within(0.001).of(Math.cos(10 * Math::PI / 180))
  end

  it 'deja fuera lo que no llega a MIN_SIMILARITY' do
    pares = described_class.new(account).all.map { |a, b, _| [a, b] }

    expect(pares).not_to include([uno.id, lejana.id])
  end

  it 'las vecinas de una sola' do
    expect(described_class.new(account).of(lejana.id).map { |a, b, _| [a, b] }).to eq([[pariente.id, lejana.id]])
  end

  it 'ignora vectores de predefinidas que ya no existen' do
    casi_uno.delete

    expect(described_class.new(account).all.flatten).not_to include(casi_uno.id)
  end
end
