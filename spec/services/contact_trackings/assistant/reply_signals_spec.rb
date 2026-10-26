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
    expect(signals('Si necesitas más información, ya sabes dónde encontrarnos.')).to be_empty
  end

  it 'marca «necesitás» y «sabés», con acento' do
    expect(signals('Si necesitás algo, ya sabés.').first[:words]).to eq(%w[necesitás sabés])
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

  # Manual de estructura (24/09/2026): varias etiquetas por ruta, como estados.
  it 'no marca una etiqueta de estado que el Entrenamiento declara con su significado' do
    ran = "[ETIQUETAS]\n#cotizar2 = el requerimiento ya se entiende y se canaliza"

    expect(signals('Listo, lo paso a un asesor. #cotizar2', ran: ran)).to be_empty
  end

  it 'sí marca la que está suelta en [ETIQUETAS], sin significado (la 173)' do
    ran = "[ETIQUETAS]\n#humano\n\n[ESTILO]\nBreve."

    expect(signals('Claro. #humano', ran: ran).first).to include(code: 'wrong_tag', tags: ['#humano'])
  end

  describe 'el agendado que toma el turno de otra ruta' do
    let(:ran) do
      "@ruta(agendar #agendar: quiero cita): - -> @agendar_calendar\n" \
        '@ruta(urgencias #urgencia: se envenenó): - -> @crear_ticket(tipo=Soporte)'
    end
    let(:horarios) { "Puedo agendarte:\n\n1️⃣ viernes 25 sep · 09:00 – 09:30 hs\n2️⃣ viernes 25 sep · 09:30 – 10:00 hs" }

    it 'lo marca, con causa motor, si la ruta del mensaje no agenda' do
      urgencia = { tag: '#urgencia', routes: { chosen: 'urgencias' } }

      expect(signals(horarios, ran: ran, ruta: urgencia)).to include(code: 'calendar_took_over', route: 'urgencias', cause: 'motor')
    end

    it 'no lo marca en la ruta que agenda' do
      agenda = { tag: '#agendar', routes: { chosen: 'agendar' } }

      expect(signals(horarios, ran: ran, ruta: agenda)).to be_empty
    end
  end

  it 'sin ruta conocida no juzga la etiqueta' do
    expect(signals('Claro. #humano', ruta: nil)).to be_empty
  end
end
