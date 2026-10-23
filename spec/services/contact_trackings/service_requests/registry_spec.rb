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

  it 'el caso que todavía no tenía fecha se completa al recibirla, no se duplica (observación SSUSA 9)' do
    primero = registrar(grua(date_text: nil, time_text: nil)).first.ticket

    otra_vez = registrar(grua).first
    expect([otra_vez.created, otra_vez.ticket.id]).to eq([false, primero.id])
  end

  it 'con case_ref actualiza ese caso aunque cambien el lugar y la capacidad (observación SSUSA 9)' do
    primero = registrar(grua).first.ticket
    corregido = grua(label: 'Grúa 50 t', stops: [{ 'tipo' => 'origen', 'lugar' => 'Centro' }, { 'tipo' => 'destino', 'lugar' => 'Paraíso' }],
                     case_ref: 1)

    otra_vez = registrar(corregido).first
    expect([otra_vez.created, otra_vez.ticket.id, otra_vez.ticket.title]).to eq([false, primero.id, 'Grúa 50 t — Centro → Paraíso'])
    expect(otra_vez.ticket.metadata['servicio']).not_to have_key('case_ref')
  end

  it 'un caso incompleto del mismo equipo se corrige aunque la IA no dé el número; «adicional» abre otro' do
    registrar(grua(date_text: nil, stops: []))

    expect(registrar(grua(label: 'Grúa 50 t', stops: [{ 'lugar' => 'Centro' }])).first.created).to be(false)
    otra = described_class.new(tracking: nil, message: mensaje, escalation: '@solicitudes -> @crear_ticket',
                               timezone: 'America/Mexico_City', text: 'además otra grúa')
    adicional = otra.register!([grua(date_text: nil, stops: [])])
    expect(adicional.first.created).to be(true)
  end

  it '«además otro» abre otro caso aunque coincidan equipo, fecha y origen (prueba conv. 391)' do
    registrar(grua)
    otra = described_class.new(tracking: nil, message: mensaje, escalation: '@solicitudes -> @crear_ticket',
                               timezone: 'America/Mexico_City', text: 'Necesito además otra grúa igual')

    expect(otra.register!([grua]).first.created).to be(true)
  end

  context 'with campos en el tipo de caso (observación SSUSA 2)' do
    let(:extractor) { instance_double(Cases::Ai::FieldExtractor, available?: true) }

    before do
      CaseTypeField.create!(account: account, case_type: case_type, key: 'material', label: 'Material', field_type: 'text', required: true)
      CaseTypeField.create!(account: account, case_type: case_type, key: 'peso', label: 'Peso', field_type: 'text', required: true)
      allow(Cases::Ai::FieldExtractor).to receive(:new).and_return(extractor)
    end

    it 'guarda los que vienen en la solicitud y anota los obligatorios que faltan' do
      allow(extractor).to receive(:extract).and_return('values' => { 'material' => 'escombro' })

      caso = registrar(grua).first.ticket
      expect(caso.custom_attributes['material']).to eq('escombro')
      expect(caso.metadata['faltan_campos']).to eq(['peso'])
      expect(ContactTrackings::ServiceRequests::Fields.missing_labels(caso)).to eq(['Peso'])
    end

    it 'con @solicitudes(asignar=peso) ese campo no lo llena la IA ni se pide: lo pone la unidad apartada' do
      allow(extractor).to receive(:extract).and_return('values' => { 'material' => 'escombro', 'peso' => 't' })

      caso = described_class.new(tracking: nil, message: mensaje, timezone: 'America/Mexico_City',
                                 escalation: '@solicitudes(asignar=peso) -> @crear_ticket(tipo=Solicitud de transporte)')
                            .register!([grua]).first.ticket
      expect([caso.custom_attributes['peso'], caso.metadata['faltan_campos'], caso.metadata['campo_asignado']]).to eq([nil, [], 'peso'])
    end

    it 'la respuesta del cliente completa el caso (complete!) sin borrar lo que ya tenía' do
      allow(extractor).to receive(:extract).and_return({ 'values' => { 'material' => 'escombro' } }, { 'values' => { 'peso' => '14 t' } })
      caso = registrar(grua).first.ticket

      described_class.new(tracking: nil, message: mensaje, escalation: '', timezone: 'America/Mexico_City', text: 'pesa 14 t').complete!(caso)
      expect(caso.reload.custom_attributes.slice('material', 'peso')).to eq('material' => 'escombro', 'peso' => '14 t')
      expect(caso.metadata['faltan_campos']).to eq([])
    end
  end
end
