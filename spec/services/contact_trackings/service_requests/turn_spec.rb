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
    expect(texto).to start_with('Recibí 2 servicios:')
    expect(texto).to include('1️⃣ Grúa 60 t · km 14+500 → Blue Giant · sáb 29 may 08:00')
    expect(texto).to include('Para programarlos me falta: del 2️⃣ la fecha y dónde es.')
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
    expect(texto).to include('Plana 40 t · km 14 · sáb 29 may · 📌 apartado')
    expect(apartado.reload.metadata['oferta']).to be_nil
  end
end
