# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — revisión de conversaciones: lo que se comprueba sin IA
RSpec.describe ContactTrackings::Assistant::ReplySignals do
  let(:replay) { { tag: '#agendar', routes: { chosen: 'agendar_cita' } } }

  def signals(texto, ran: 'Háblale de tú.', current: nil, ruta: replay)
    described_class.new(ran: ran, current: current).call(texto, ruta)
  end

  it 'marca el voseo, y lo culpa al motor si el Entrenamiento no lo tiene' do
    expect(signals('Ya tenés una cita. ¿Qué preferís?')).to eq(
      [{ code: 'voseo', words: %w[tenés preferís], cause: 'motor' }]
    )
  end

  it 'culpa al Entrenamiento si él mismo está en voseo (el modelo lo imita)' do
    expect(signals('Si querés, te ayudo', ran: 'Si el cliente querés algo…').first[:cause]).to eq('entrenamiento')
  end

  it 'no marca el tú' do
    expect(signals('Ya tienes una cita. ¿Qué prefieres?')).to be_empty
  end

  it 'la etiqueta de su ruta no es error: el motor la pone a propósito' do
    expect(signals("Claro, te ayudo.\n\n#agendar")).to be_empty
  end

  it 'marca una etiqueta que no es la de su ruta' do
    expect(signals('Claro, te ayudo. #humano')).to eq(
      [{ code: 'wrong_tag', tags: ['#humano'], expected: '#agendar', route: 'agendar_cita',
         cause: 'entrenamiento', already_fixed: false }]
    )
  end

  it 'la da por corregida si el agente ya no la tiene (la conversación usa una copia vieja)' do
    expect(signals('Claro. #humano', current: '@ruta(agendar_cita #agendar: citas): -').first[:already_fixed]).to be(true)
  end

  it 'sin ruta conocida no juzga la etiqueta' do
    expect(signals('Claro. #humano', ruta: nil)).to be_empty
  end
end
