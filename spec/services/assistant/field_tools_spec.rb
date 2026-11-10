# frozen_string_literal: true

require 'rails_helper'

# Dali — trabajo en campo: la ruta del día, el detalle de la visita, «voy en camino» y el
# reporte dictado (orden: bitácora + lista; visita agendada: reporte de cierre y realizada).
RSpec.describe Assistant::FieldTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator, name: 'Luis Técnico') }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:zone) { ActiveSupport::TimeZone['America/Mexico_City'] }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: zone) }
  let(:contact) { create(:contact, account: account, name: 'Jane Pérez', phone_number: '+5215512345678') }
  let(:orden) { CaseType.create!(account: account, name: 'Mantenimiento A/C', color: '#0d9488', case_class: :work_order) }
  let(:order) do
    CaseTicket.create!(account: account, title: 'Mantenimiento', contact: contact, case_type: orden, assignee: user,
                       work_address: 'Av. Reforma 123')
  end
  let!(:visit) do
    at = Time.zone.now.change(hour: 9)
    CaseMeeting.create!(account: account, contact: contact, title: 'Visita a Jane', starts_at: at, ends_at: at + 1.hour,
                        organizer: user, is_visit: true, location: 'Polanco')
  end

  before do
    Current.user = user
    at = Time.zone.now.change(hour: 15)
    CaseMeeting.create!(account: account, case_ticket: order, title: 'Visita OT', starts_at: at, ends_at: at + 1.hour, organizer: user)
    create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact)
  end

  after { Current.user = nil }

  it 'trae la ruta de hoy en orden de hora, con kind e id para seguir' do
    rows = tools.call('my_route', {})[:result][:visits]
    expect(rows.pluck(:kind, :id, :title)).to eq([['visit', visit.id, 'Visita a Jane'], ['order', order.id, 'Mantenimiento']])
    expect(rows.last).to include(client: 'Jane Pérez', address: 'Av. Reforma 123', state: 'pending')
  end

  it 'el detalle de la orden trae la lista y las visitas anteriores al cliente' do
    order.case_tasks.create!(account: account, title: 'Limpiar filtros', requester: user)
    before = CaseTicket.create!(account: account, title: 'Instalación', contact: contact, case_type: orden, status: :closed)
    before.work_logs.create!(account: account, user: user, kind: :note, content: 'Se instaló el equipo')
    detail = tools.call('get_visit', { 'kind' => 'order', 'id' => order.id })[:result]
    expect(detail[:checklist].pluck(:title)).to eq(['Limpiar filtros'])
    expect(detail[:previous_visits].first).to include(folio: before.folio, notes: ['Se instaló el equipo'])
  end

  it 'voy en camino de una orden avisa al cliente por su conversación' do
    proposal = tools.call('propose_on_my_way', { 'kind' => 'order', 'id' => order.id, 'eta_minutes' => 20 })[:proposal]
    expect(proposal['labels']['rows']).to include(['CLIENT', 'Jane Pérez'])
    executor.call('on_my_way', proposal['payload'])
    expect(order.case_events.where("payload ->> 'field' = 'on_my_way'")).to exist
    # La hora del aviso es la del usuario, no la del servidor.
    eta = 20.minutes.from_now.in_time_zone(zone).strftime('%H:%M')
    expect(order.case_events.last.payload['eta']).to eq(eta)
  end

  it 'voy en camino de una visita agendada marca la hora' do
    proposal = tools.call('propose_on_my_way', { 'kind' => 'visit', 'id' => visit.id, 'eta_minutes' => 15 })[:proposal]
    executor.call('on_my_way', proposal['payload'])
    expect(visit.reload.on_my_way_at).to be_present
  end

  it 'el reporte dictado de la orden queda en la bitácora y marca los puntos de la lista' do
    filtros = order.case_tasks.create!(account: account, title: 'Limpiar filtros', requester: user)
    gas = order.case_tasks.create!(account: account, title: 'Revisar gas', requester: user)
    proposal = tools.call('propose_visit_report', { 'kind' => 'order', 'id' => order.id, 'notes' => 'Cambié el capacitor.',
                                                    'done_task_ids' => [filtros.id, 999] })[:proposal]
    expect(proposal['payload']['done_task_ids']).to eq([filtros.id])
    expect(proposal['labels']['checklist'].pluck('title', 'checked')).to eq([['Limpiar filtros', true], ['Revisar gas', false]])

    result = executor.call('visit_report', proposal['payload'])
    expect(order.work_logs.note.last.content).to eq('Cambié el capacitor.')
    expect(filtros.reload).to be_done
    expect(gas.reload).to be_pending
    expect(result['path']).to end_with("/campo/visita/#{order.id}")
  end

  it 'el reporte de una visita agendada crea el reporte de cierre y la deja realizada' do
    proposal = tools.call('propose_visit_report', { 'kind' => 'visit', 'id' => visit.id, 'notes' => 'Le presenté el plan anual.' })[:proposal]
    expect(proposal['labels']['closes_visit']).to be(true)
    executor.call('visit_report', proposal['payload'].merge('minutes' => 45))
    report = visit.task_reports.last
    expect(report).to have_attributes(content: 'Le presenté el plan anual.', minutes: 45)
    expect(report.closed_at).to be_present
    expect(visit.reload).to be_held
  end

  it 'no deja reportar visitas ajenas' do
    other = create(:user, account: account)
    alien = CaseMeeting.create!(account: account, contact: contact, title: 'Ajena', starts_at: Time.current, ends_at: 1.hour.from_now,
                                organizer: other, is_visit: true)
    seller = instance_double(Access::Grant, case_tickets: account.case_tickets.none)
    seller_tools = Assistant::Tools.new(account: account, user: user, grant: seller, zone: zone)
    result = seller_tools.call('propose_visit_report', { 'kind' => 'visit', 'id' => alien.id, 'notes' => 'x' })
    expect(result[:result][:error]).to be_present
  end
end
