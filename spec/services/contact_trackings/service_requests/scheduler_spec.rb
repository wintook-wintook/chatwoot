require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Scheduler do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:tracking) { create(:contact_tracking, account: account, inbox: inbox, conversation: conversation) }
  let(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:ruta) do
    ContactTrackings::RouteMap::Route.new(name: 's', escalation: '@solicitudes -> @crear_ticket -> @agendar_calendar(duracion=?, horario=24h) ' \
                                                                 '-> {{hoja_buscar: Equipos | tipo=? | Calendar_ID}}')
  end
  let(:buscador) { instance_double(ContactTrackings::AvailabilitySlotService) }
  let(:tz) { 'America/Mexico_City' }
  let(:pedido) { Time.find_zone(tz).local(2027, 10, 5, 9) }

  def slot(hora, cal = 'TP-1')
    inicio = Time.find_zone(tz).local(2027, 10, 5, hora)
    { slot: inicio, end_time: inicio + 3.hours, calendar_integration_id: 1, google_calendar_id: cal, calendar_name: cal }
  end

  def caso(datos)
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, case_type: case_type, title: 'x',
                       metadata: { 'servicio' => { 'equipment_type' => 'plana', 'duration_text' => '3 horas' }.merge(datos) })
  end

  def planear(datos)
    agenda = described_class.new(tracking: tracking, route: ruta, timezone: tz)
    allow(agenda).to receive(:slot_service).and_return(buscador)
    agenda.plan(caso(datos), 1)
  end

  it 'con hora pedida libre, esa es la opción A (se ofrece, no se aparta)' do
    allow(buscador).to receive_messages(slot_for: slot(9), call: [slot(9), slot(10)])

    plan = planear('date' => '2027-10-05', 'time' => '09:00')
    expect(plan.offers.pluck('code')).to eq(%w[1A 1B])
    expect(plan.note).to be_nil
    expect(plan.ticket.reload.metadata['oferta'].size).to eq(2)
  end

  it 'con hora ocupada, lo dice y ofrece las siguientes' do
    allow(buscador).to receive_messages(slot_for: nil, call: [slot(10), slot(11), slot(12), slot(13)])

    plan = planear('date' => '2027-10-05', 'time' => '09:00')
    expect([plan.note, plan.offers.size]).to eq(['09:00 ocupado', 3])
  end

  it 'fecha pasada o equipo que no está en la hoja' do
    expect(planear('date' => '2020-01-01').note).to eq('esa fecha ya pasó')

    agenda = described_class.new(tracking: tracking, route: ruta, timezone: tz)
    allow(agenda).to receive(:slot_service).and_return(nil)
    expect(agenda.plan(caso('date' => '2027-10-05'), 1).note).to eq('no tengo ese equipo en el catálogo')
  end

  it 'una renta de 6 meses ofrece los equipos libres todo el periodo (F7)' do
    libre = slot(0).merge(all_day: true, calendar_name: 'GR-90')
    allow(buscador).to receive(:free_for_period).and_return([libre])

    plan = planear('date' => '2027-11-01', 'duration_text' => '6 meses')
    expect(buscador).to have_received(:free_for_period).with(Time.find_zone(tz).local(2027, 11, 1), Time.find_zone(tz).local(2028, 5, 1))
    expect(plan.offers.first).to include('code' => '1A', 'all_day' => true)
  end
end
