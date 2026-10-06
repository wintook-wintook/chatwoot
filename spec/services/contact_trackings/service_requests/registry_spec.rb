require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Registry do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let!(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:servicio) { ContactTrackings::ServiceRequests::Extractor::Service }

  before { allow(Cases::RuleEngineService).to receive(:new).and_return(instance_double(Cases::RuleEngineService, evaluate!: true)) }

  def mensaje
    create(:message, account: account, inbox: inbox, conversation: conversation, content: 'solicitud')
  end

  def registrar(*servicios)
    described_class.new(tracking: nil, message: mensaje, escalation: '@solicitudes -> @crear_ticket(tipo=Solicitud de transporte, prioridad=alta)',
                        timezone: 'America/Mexico_City').register!(servicios)
  end

  def grua(**cambios)
    servicio.new(label: 'Grúa 60 t', equipment_type: 'grúa', stops: [{ 'tipo' => 'origen', 'lugar' => 'km 14+500' }],
                 date_text: '29 de mayo 2027', time_text: '08:00 am', folios: [], **cambios)
  end

  it 'un caso por servicio, con el tipo y la prioridad de la ruta y sus datos' do
    entries = registrar(grua, servicio.new(label: 'Hiab', equipment_type: 'hiab', stops: [], folios: []))

    expect(entries.map(&:created)).to eq([true, true])
    caso = entries.first.ticket
    expect([caso.case_type, caso.priority, caso.conversation_id]).to eq([case_type, 'high', conversation.id])
    expect(caso.metadata['servicio'].slice('date', 'time')).to eq('date' => '2027-05-29', 'time' => '08:00')
    expect(caso.description).to include('Ruta: origen: km 14+500')
  end

  it '«02 camiones con hiab» en el mismo mensaje son dos casos' do
    hiab = servicio.new(label: 'Hiab 10 t', equipment_type: 'hiab', stops: [{ 'lugar' => 'Blue Giant' }], date_text: 'mañana', folios: [])

    expect(registrar(hiab, hiab.dup).map(&:created)).to eq([true, true])
  end

  it 'la reiteración en otro mensaje actualiza el caso abierto (último dato gana)' do
    primero = registrar(grua).first.ticket

    otra_vez = registrar(grua(time_text: '09:00 am', notes: 'datos de personal para accesos')).first
    expect(otra_vez.created).to be(false)
    expect(otra_vez.ticket.id).to eq(primero.id)
    expect(otra_vez.ticket.metadata['servicio'].slice('time', 'notes')).to eq('time' => '09:00', 'notes' => 'datos de personal para accesos')
  end

  it 'otra fecha u otro equipo es otro servicio' do
    registrar(grua)

    expect(registrar(grua(date_text: '30 de mayo 2027')).first.created).to be(true)
  end

  it '«camión con grúa tipo hiab» y «Hiab» son el mismo equipo al reiterar' do
    hiab = servicio.new(label: 'Hiab', equipment_type: 'camión con grúa tipo hiab', stops: [{ 'lugar' => 'km 14+500' }],
                        date_text: '29 de mayo 2027', folios: [])
    registrar(hiab)

    expect(registrar(hiab.dup.tap { |h| h.equipment_type = 'hiab' }).first.created).to be(false)
  end
end
