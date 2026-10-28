require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Block do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:tz) { 'America/Mexico_City' }
  let(:inicio) { Time.find_zone(tz).local(2026, 10, 21, 12) }
  let(:plan_class) { ContactTrackings::ServiceRequests::Scheduler::Plan }
  let(:caso) do
    datos = { 'label' => 'Rabón', 'date' => '2026-10-21', 'time' => '12:00',
              'stops' => [{ 'lugar' => 'Carmen' }, { 'lugar' => 'Villahermosa' }] }
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, title: 'Rabón',
                       metadata: { 'servicio' => datos })
  end

  def oferta(codigo, horas, unidad)
    { 'code' => codigo, 'slot' => (inicio + horas.hours).utc.iso8601, 'end_time' => (inicio + (horas + 1).hours).utc.iso8601,
      'gcal' => "g-#{unidad}", 'calendar_name' => unidad }
  end

  def plan(**extra)
    ofertas = [oferta('1A', 0, 'TP-46'), oferta('1B', 2, 'TP-46'), oferta('1C', 4, 'TP-73')]
    plan_class.new(ticket: caso, offers: ofertas, requested: inicio, exact: true,
                   units: { 'g-TP-46' => 'Cama baja · 40 t · 16.15 m' }, **extra)
  end

  def bloque(canal, **)
    allow(inbox).to receive(:channel_type).and_return(canal)
    described_class.new(conversation: conversation, timezone: tz).service(caso, **)
  end

  it 'en WhatsApp: el bloque del documento, con la tabla alineada en ``` y sin pasar de 30 caracteres' do
    texto = bloque('Channel::Whatsapp', plan: plan, missing: ['ubicación de destino'])

    expect(texto).to eq(<<~TEXTO.chomp)
      *Servicio 1* · Carmen → Villahermosa
      Cama baja · 40 t · 16.15 m
      mié 21 oct · Caso #{caso.folio}
      Estado: Por confirmar (la de las 12:00 es la que pediste)
      ```
      Op  Horario      Unidad
      A   12:00-13:00  TP-46
      B   14:00-15:00  TP-46
      C   16:00-17:00  TP-73
      ```
      Falta: ubicación de destino
    TEXTO
    tabla = texto[/```\n(.*)\n```/m, 1].lines
    expect(tabla.map { |renglon| renglon.chomp.size }.max).to be <= described_class::WIDTH
  end

  it 'en Telegram el título va con ** (CommonMarker → <strong>); en otros canales, sin bloque' do
    expect(bloque('Channel::Telegram', plan: plan)).to start_with('**Servicio 1** · ').and include("```\nOp  Horario")

    texto = bloque('Channel::Api', plan: plan)
    expect(texto).to start_with('Servicio 1 · Carmen → Villahermosa').and include("A · 12:00-13:00 · TP-46\nB · 14:00-15:00 · TP-46")
    expect(texto).not_to include('```')
  end

  it 'opciones de otro día llevan el día; la nota de la hora ocupada va en su renglón' do
    otro_dia = plan_class.new(ticket: caso, offers: [oferta('1A', 24, 'TP-46')], requested: inicio, exact: false,
                              note: 'a las 12:00 no hay, ni más tarde ese día')

    texto = bloque('Channel::Whatsapp', plan: otro_dia)
    expect(texto).to include("Estado: Por confirmar\nA las 12:00 no hay, ni más tarde ese día.").and include('A   jue 22 12:00-13:00  TP-46')
  end

  it 'apartado: estado y horario, sin tabla' do
    caso.update!(metadata: caso.metadata.merge('estado' => 'apartado'))

    texto = bloque('Channel::Whatsapp', held: oferta('1A', 0, 'TP-46'))
    expect(texto).to include("Estado: Apartado\nHorario: 12:00-13:00 · TP-46")
    expect(texto).not_to include('```')
  end

  it 'lo más parecido va antes de la unidad' do
    texto = bloque('Channel::Whatsapp', plan: plan(related: 'no tengo rabón; lo más parecido que tengo:'))
    expect(texto).to include("No tengo rabón; lo más parecido que tengo:\nCama baja · 40 t")
  end
end
