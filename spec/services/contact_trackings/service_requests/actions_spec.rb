require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Actions do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:ruta_confirmar) { ContactTrackings::RouteMap::Route.new(name: 'c', escalation: '@confirmar_servicio') }
  let(:tarea) { instance_double(ContactTrackings::ServiceMeeting, confirm!: true, cancel!: true) }

  before do
    allow(ContactTrackings::ServiceMeeting).to receive(:new).and_return(tarea)
    allow(CaseMeeting).to receive(:find_by).and_return(instance_double(CaseMeeting, cancelled?: false))
  end

  def caso(label, tipo, estado = 'apartado')
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, case_type: case_type, title: label,
                       metadata: { 'servicio' => { 'label' => label, 'equipment_type' => tipo }, 'estado' => estado, 'meeting_id' => 1 })
  end

  def accion(texto, ruta: nil)
    mensaje = create(:message, account: account, inbox: inbox, conversation: conversation, content: texto)
    described_class.new(tracking: nil, message: mensaje, branch: ruta, timezone: 'America/Mexico_City').call
  end

  it 'confirmar sin decir cuál: todos los apartados quedan en firme' do
    caso('Plana 40 t', 'plana')
    caso('Cama baja', 'cama baja')

    expect(accion('Le confirmamos el servicio', ruta: ruta_confirmar)).to start_with('✅ Confirmé:')
    expect(tarea).to have_received(:confirm!).twice
  end

  it '«confirmo el 2» con pago requerido: solo ese queda esperando el pago' do
    uno = caso('Plana 40 t', 'plana')
    dos = caso('Cama baja', 'cama baja')
    pago = ContactTrackings::RouteMap::Route.new(name: 'c', escalation: '@confirmar_servicio(requiere=pago)')

    expect(accion('confirmo el 2', ruta: pago)).to include('necesitamos el pago por adelantado')
    expect([uno.reload.metadata['estado'], dos.reload.metadata['estado']]).to eq(%w[apartado esperando_pago])
  end

  it '«cancela el hiab» cancela solo ese caso y su tarea' do
    caso('Plana 40 t', 'plana')
    hiab = caso('Hiab 12 t', 'hiab')

    expect(accion('cancela el hiab por favor')).to include('Listo, cancelé:').and include('Hiab 12 t')
    expect(hiab.reload.status).to eq('cancelled')
    expect(tarea).to have_received(:cancel!).once
  end

  it 'cancelar con varios y sin decir cuál: pregunta' do
    caso('Plana 40 t', 'plana')
    caso('Hiab 12 t', 'hiab')

    expect(accion('ya no lo necesito, cancélalo')).to start_with('¿Cuál quieres cancelar?')
  end

  it 'un mensaje que no es acción no interviene' do
    caso('Plana 40 t', 'plana')

    expect(accion('¿qué medidas tiene la plana?')).to be_nil
  end
end
