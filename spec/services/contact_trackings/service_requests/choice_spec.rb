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

  it 'sin ofertas abiertas o si el mensaje no elige nada, no interviene' do
    expect(elegir('1A')).to be_nil
    caso('Plana 40 t', %w[1A])
    expect(elegir('¿y cuánto cuesta?')).to be_nil
  end
end
