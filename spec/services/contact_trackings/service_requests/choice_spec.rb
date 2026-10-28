require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Choice do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:tarea) { instance_double(CaseMeeting, id: 9, starts_at: inicio, ends_at: inicio + 3.hours, sync_failed?: false, reload: nil) }
  let(:inicio) { Time.zone.parse('2026-10-05 15:00 UTC') }

  def caso(label, codigos)
    ofertas = codigos.map do |c|
      { 'code' => c, 'slot' => inicio.iso8601, 'end_time' => (inicio + 3.hours).iso8601, 'cal_id' => 1, 'gcal' => "g#{c}",
        'calendar_name' => "TP-#{c}" }
    end
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, case_type: case_type, title: label,
                       metadata: { 'servicio' => { 'label' => label }, 'oferta' => ofertas })
  end

  def elegir(texto, tentative: true)
    mensaje = create(:message, account: account, inbox: inbox, conversation: conversation, content: texto)
    described_class.new(tracking: nil, message: mensaje, timezone: 'America/Mexico_City', tentative: tentative).call
  end

  before do
    allow(tarea).to receive(:reload).and_return(tarea)
    allow(ContactTrackings::ServiceMeeting).to receive(:hold!).and_return(tarea)
  end

  it '«1A y 2B» aparta esas dos, cada una en su calendario, y dice cuál falta' do
    caso('Plana 40 t', %w[1A 1B])
    caso('Cama baja', %w[2A 2B])
    caso('Hiab', %w[3A])

    texto = elegir('1A y 2B')
    expect(ContactTrackings::ServiceMeeting).to have_received(:hold!).with(hash_including(slot: hash_including(google_calendar_id: 'g1A')))
    expect(ContactTrackings::ServiceMeeting).to have_received(:hold!).with(hash_including(slot: hash_including(google_calendar_id: 'g2B')))
    expect(texto).to start_with('📌 Aparté:').and include('Falta elegir horario de: 3️⃣.')
  end

  it '«sí» aparta la primera opción de cada servicio' do
    caso('Plana 40 t', %w[1A 1B])
    caso('Cama baja', %w[2A])

    elegir('sí, apártalos')
    expect(ContactTrackings::ServiceMeeting).to have_received(:hold!).twice
  end

  it 'sin modo tentativo, lo deja en firme' do
    caso('Plana 40 t', %w[1A])
    firme = instance_double(ContactTrackings::ServiceMeeting, confirm!: true)
    allow(ContactTrackings::ServiceMeeting).to receive(:new).and_return(firme)

    expect(elegir('1A', tentative: false)).to start_with('✅ Agendé:')
    expect(firme).to have_received(:confirm!)
  end

  it 'con @solicitudes(asignar=unidad), la unidad apartada queda en ese campo del caso' do
    servicio = caso('Plana 40 t', %w[1A])
    servicio.update!(metadata: servicio.metadata.merge('campo_asignado' => 'unidad'))

    elegir('1A')
    expect(servicio.reload.custom_attributes['unidad']).to eq('TP-1A')
  end

  it 'sin ofertas abiertas o si el mensaje no elige nada, no interviene' do
    expect(elegir('1A')).to be_nil
    caso('Plana 40 t', %w[1A])
    expect(elegir('¿y cuánto cuesta?')).to be_nil
  end

  describe 'respuestas naturales (observaciones SSUSA 22/10, F1)' do
    let(:interprete) { instance_double(ContactTrackings::ServiceRequests::Interpreter) }
    let(:resultado) { ContactTrackings::ServiceRequests::Interpreter::Result }

    def la_ia_lee(action, general: false, codes: [])
      allow(ContactTrackings::ServiceRequests::Interpreter).to receive(:new).and_return(interprete)
      allow(interprete).to receive(:call).and_return(resultado.new(action: action, general: general, codes: codes))
    end

    it 'sin IA, «Adelante con el horario» aparta la opción ofrecida (ejemplo real)' do
      caso('Rabón', %w[1A])

      expect(elegir('Adelante con el horario')).to start_with('📌 Aparté:')
      expect(ContactTrackings::ServiceMeeting).to have_received(:hold!).once
    end

    it '«el 2 a las 16» no es el código 2A' do
      caso('Plana 40 t', %w[1A])
      caso('Cama baja', %w[2A 2B])
      la_ia_lee(:otra)

      expect(elegir('el 2 a las 16')).to be_nil
      expect(ContactTrackings::ServiceMeeting).not_to have_received(:hold!)
    end

    it 'aparta lo que la IA ubicó («la de las 14» → 1B)' do
      caso('Plana 40 t', %w[1A 1B])
      la_ia_lee(:elegir, codes: ['1B'])

      elegir('la de las 14')
      expect(ContactTrackings::ServiceMeeting).to have_received(:hold!).with(hash_including(slot: hash_including(google_calendar_id: 'g1B')))
    end

    it 'con varias opciones, la afirmación general toma la A y lo dice' do
      caso('Plana 40 t', %w[1A 1B])
      la_ia_lee(:elegir, general: true)

      expect(elegir('va')).to start_with('Aparté la opción A de cada servicio.')
    end

    it 'si no se sabe cuál, una sola pregunta con las opciones y no aparta nada' do
      caso('Plana 40 t', %w[1A 1B])
      la_ia_lee(:ambigua)

      texto = elegir('sí pero más tarde')
      expect(texto).to start_with('¿Cuál horario prefieres?').and include('1️⃣ Plana 40 t: 1A 09:00–12:00 (TP-1A) · 1B')
      expect(ContactTrackings::ServiceMeeting).not_to have_received(:hold!)
    end

    it '«ninguna» pide otro día u hora' do
      caso('Plana 40 t', %w[1A])
      la_ia_lee(:rechazo)

      expect(elegir('ninguna')).to eq(described_class::REJECT_TEXT)
    end
  end

  describe '¿Confirmo el servicio?' do
    let(:prompt) { "@ruta(confirmacion_servicio: confirma): - -> @confirmar_servicio\n@ruta(solicitud: pide): - -> @solicitudes" }
    let(:tracking) { instance_double(ContactTracking, complementary_prompt: prompt, inbox: inbox) }

    def elegir_con_agente(texto)
      mensaje = create(:message, account: account, inbox: inbox, conversation: conversation, content: texto)
      described_class.new(tracking: tracking, message: mensaje, timezone: 'America/Mexico_City', tentative: true).call
    end

    it 'apartado y sin datos pendientes, pregunta en el mismo mensaje; el «sí» siguiente lo confirma' do
      servicio = caso('Plana 40 t', %w[1A])
      expect(elegir_con_agente('1A')).to end_with('¿Confirmo el servicio?')
      expect(servicio.reload.metadata).to include('estado' => 'apartado', described_class::ASKED_KEY => true)

      acciones = instance_double(ContactTrackings::ServiceRequests::Actions, call: '✅ Confirmé:')
      allow(ContactTrackings::ServiceRequests::Actions).to receive(:new).and_return(acciones)
      expect(elegir_con_agente('sí, adelante')).to eq('✅ Confirmé:')
      expect(ContactTrackings::ServiceRequests::Actions).to have_received(:new)
        .with(hash_including(branch: having_attributes(name: 'confirmacion_servicio')))
    end

    it 'con datos pendientes no pregunta; sin la pregunta, un «sí» suelto no confirma' do
      servicio = caso('Plana 40 t', %w[1A])
      servicio.update!(metadata: servicio.metadata.merge(ContactTrackings::ServiceRequests::Fields::PENDING_KEY => ['destino']))

      expect(elegir_con_agente('1A')).to include('Quedan pendientes de confirmar')
      expect(elegir_con_agente('sí')).to be_nil
    end
  end
end
