require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Turn do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, content: 'grúa y hiab') }
  let(:servicio) { ContactTrackings::ServiceRequests::Extractor::Service }
  let(:ruta) { ContactTrackings::RouteMap::Route.new(name: 'solicitud', escalation: '@solicitudes -> @crear_ticket') }
  let(:extractor) { instance_double(ContactTrackings::ServiceRequests::Extractor) }

  before do
    allow(ContactTrackings::ServiceRequests::Extractor).to receive(:new).and_return(extractor)
    allow(Cases::RuleEngineService).to receive(:new).and_return(instance_double(Cases::RuleEngineService, evaluate!: true))
  end

  def turno
    described_class.new(tracking: nil, message: message, branch: ruta, timezone: 'America/Mexico_City').call
  end

  it 'responde con los servicios numerados y una sola pregunta con lo que falta' do
    allow(extractor).to receive(:call).and_return([
                                                    servicio.new(label: 'Grúa 60 t', stops: [{ 'lugar' => 'km 14+500' }, { 'lugar' => 'Blue Giant' }],
                                                                 date_text: '29 de mayo 2027', time_text: '08:00', folios: []),
                                                    servicio.new(label: 'Hiab', stops: [], folios: [])
                                                  ])

    texto = turno
    expect(texto).to start_with('Tu solicitud tiene 2 servicios:')
    expect(texto).to include("Servicio 1 · km 14+500 → Blue Giant\nGrúa 60 t\nsáb 29 may · Caso")
    expect(texto).to include("Servicio 2 · Hiab\nCaso").and include("Estado: Por confirmar\nFalta: la fecha, dónde es")
    expect(texto).to end_with('Cuando me pases lo que falta, lo programo.')
  end

  it 'sin servicios en el mensaje devuelve nil: el motor sigue como siempre' do
    allow(extractor).to receive(:call).and_return([])

    expect(turno).to be_nil
  end

  it 'al reiterar un servicio ya apartado no lo vuelve a ofrecer: dice su estado' do
    datos = { 'label' => 'Plana 40 t', 'equipment_type' => 'plana', 'date' => '2027-05-29', 'stops' => [{ 'lugar' => 'km 14' }] }
    apartado = CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, title: 'Plana',
                                  metadata: { 'servicio' => datos, 'estado' => 'apartado', 'meeting_id' => 5 })
    entry = ContactTrackings::ServiceRequests::Registry::Entry.new(ticket: apartado, created: false)
    registro = instance_double(ContactTrackings::ServiceRequests::Registry, register!: [entry])
    allow(ContactTrackings::ServiceRequests::Registry).to receive(:new).and_return(registro)
    allow(extractor).to receive(:call).and_return([servicio.new(label: 'Plana 40 t')])
    ruta_agenda = ContactTrackings::RouteMap::Route.new(name: 's', escalation: '@solicitudes -> @crear_ticket -> @agendar_calendar')
    expect(ContactTrackings::ServiceRequests::Scheduler).to receive(:new).and_call_original

    texto = described_class.new(tracking: nil, message: message, branch: ruta_agenda, timezone: 'America/Mexico_City').call
    expect(texto).to include("Servicio 1 · km 14\nPlana 40 t\nsáb 29 may · Caso").and include('Estado: Apartado')
    expect(apartado.reload.metadata['oferta']).to be_nil
  end

  describe 'opciones de @solicitudes (27/11/2026)' do
    let(:case_type) { CaseType.create!(account: account, name: 'Renta Unidades', color: '#3b82f6') }
    let(:scheduler) { instance_double(ContactTrackings::ServiceRequests::Scheduler, agenda?: true) }
    let(:datos) do
      { 'label' => 'Plana', 'equipment_type' => 'plana', 'date' => '2027-05-29', 'time' => '09:00', 'stops' => [{ 'lugar' => 'km 14' }] }
    end

    def registra(caso)
      registro = instance_double(ContactTrackings::ServiceRequests::Registry,
                                 register!: [ContactTrackings::ServiceRequests::Registry::Entry.new(ticket: caso, created: true)])
      allow(ContactTrackings::ServiceRequests::Registry).to receive(:new).and_return(registro)
    end

    def turno_con(escalacion, metadata)
      registra(CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, title: 'Plana', case_type: case_type,
                                  metadata: { 'servicio' => datos }.merge(metadata)))
      allow(extractor).to receive(:call).and_return([servicio.new(label: 'Plana')])
      rama = ContactTrackings::RouteMap::Route.new(name: 's', escalation: escalacion)
      described_class.new(tracking: nil, message: message, branch: rama, timezone: 'America/Mexico_City').call
    end

    before do
      %w[material peso medidas].each_with_index do |clave, i|
        CaseTypeField.create!(account: account, case_type: case_type, key: clave, label: clave.capitalize, field_type: 'text', required: true,
                              position: i)
      end
    end

    def con_agenda
      allow(ContactTrackings::ServiceRequests::Scheduler).to receive(:new).and_return(scheduler)
      allow(scheduler).to receive(:plan).and_return(ContactTrackings::ServiceRequests::Scheduler::Plan.new(offers: []))
    end

    it 'sin datos=primero, como siempre: calcula horarios aunque falten datos' do
      con_agenda

      turno_con('@solicitudes -> @crear_ticket -> @agendar_calendar', 'faltan_campos' => %w[peso])
      expect(scheduler).to have_received(:plan)
    end

    it 'con datos=primero no ofrece horarios mientras falte un obligatorio' do
      con_agenda

      texto = turno_con('@solicitudes(datos=primero) -> @crear_ticket -> @agendar_calendar', 'faltan_campos' => %w[peso])
      expect(scheduler).not_to have_received(:plan)
      expect(texto).to include('Falta: Peso').and end_with('Cuando me pases lo que falta, lo programo.')
    end

    it 'con datos=primero y todo completo, sí ofrece horarios' do
      con_agenda

      turno_con('@solicitudes(datos=primero) -> @crear_ticket -> @agendar_calendar', 'faltan_campos' => [])
      expect(scheduler).to have_received(:plan)
    end

    it 'con faltan=2 pide como máximo dos datos por mensaje' do
      texto = turno_con('@solicitudes(faltan=2) -> @crear_ticket', 'faltan_campos' => %w[material peso medidas])

      expect(texto).to include('Falta: Material, Peso')
      expect(texto).not_to include('Medidas')
    end

    it 'con la fecha que ya pasó pide otra, en vez de «un asesor revisa»' do
      datos.merge!('date' => nil, 'time' => nil, 'past_date' => '2026-11-26', 'past_time' => '14:00')

      texto = turno_con('@solicitudes -> @crear_ticket -> @agendar_calendar', 'faltan_campos' => [])
      expect(texto).to include('Falta: otra fecha u hora (la que me diste ya pasó)')
      expect(texto).to end_with('Cuando me pases lo que falta, lo programo.')
      expect(texto).not_to include('Un asesor revisa')
    end
  end
end
