# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::StagedOfferImages do
  let(:definition) do
    ContactTrackings::ConversationVariables.parse("[VARIABLES]\nSIGUIENTE_OFERTA = PRIMERA_BECA | SEGUNDA_BECA | AGOTADA\n")
  end
  let(:ficha) do
    <<~FICHA
      COSTOS Y BECAS
      - Precio normal por materia: $3,221.00
      - Primera beca: 38% toda la Licenciatura, paga $ 1,990.00 por materia, cupón: l0601202611.
      {{tsbeca1mat}}
      - Segunda beca: 52% los 3 primeros cuatrimestres, paga $ 1,540.00 y 38% el resto, $ 1,990.00, cupón: l0602202611.
      {{tsbeca2mat}}
      - Última beca: NO HAY
    FICHA
  end
  let(:solo_primera) do
    KnowledgeBase::StagedOffers.filter(ficha, definition, { 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA' })
  end

  def con_imagenes(reply, contexto = ficha) = described_class.call(reply, contexto, definition)

  it 'dio la primera beca sin su imagen → se agrega (dev conv 278)' do
    reply = 'Contamos con una beca del 38%: paga $1,990.00 por materia con el cupón l0601202611.'
    expect(con_imagenes(reply, solo_primera)).to eq("#{reply}\n{{tsbeca1mat}}")
  end

  it 'si ya trae su imagen, no la repite' do
    reply = "Beca del 38% con el cupón l0601202611.\n{{tsbeca1mat}}"
    expect(con_imagenes(reply, solo_primera)).to eq(reply)
  end

  it 'con las dos a la vista, la segunda se reconoce por lo que solo ella tiene (52%, su cupón)' do
    reply = 'La segunda beca es del 52% los primeros 3 cuatrimestres y 38% el resto.'
    expect(con_imagenes(reply)).to eq("#{reply}\n{{tsbeca2mat}}")
  end

  it 'el 38% y $1,990.00 están en las dos: con las dos a la vista no bastan para decir que dio la primera' do
    reply = 'Con la beca pagaría $1,990.00 por materia (38%).'
    expect(con_imagenes(reply)).to eq(reply)
  end

  it 'una respuesta que no entrega becas no cambia' do
    reply = 'Esta es la mejor opción que tenemos disponible para la Licenciatura en Trabajo Social.'
    expect(con_imagenes(reply)).to eq(reply)
  end

  it 'sin variable de siguiente oferta no hace nada' do
    otra = ContactTrackings::ConversationVariables.parse("[VARIABLES]\nCARRERA = VACÍO | valor\n")
    reply = 'Beca del 38% con el cupón l0601202611.'
    expect(described_class.call(reply, ficha, otra)).to eq(reply)
  end
end
