# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a: datos de la orden, materiales y
# cierre con conformidad.
RSpec.describe 'Case Tickets API — órdenes de trabajo' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:orden)   { CaseType.create!(account: account, name: 'Visita técnica', color: '#0d9488', case_class: :work_order) }
  let(:base)    { "/api/v1/accounts/#{account.id}/case_tickets" }

  def work_order(attrs = {})
    CaseTicket.create!({ account: account, title: 'Instalar equipo', contact: contact, case_type: orden,
                         status: :in_progress }.merge(attrs))
  end

  def column(label)
    orden.case_type_columns.find_by!(label: label)
  end

  def patch_json(url, params)
    patch url, params: params, headers: admin.create_new_auth_token, as: :json
  end

  def post_json(url, params)
    post url, params: params, headers: admin.create_new_auth_token, as: :json
  end

  it 'crea con cliente o sin él (orden interna) y expone los datos' do
    post_json(base, case_ticket: { contact_id: contact.id, case_type_id: orden.id, title: 'Instalación',
                                   work_address: ' Av. Juárez 10 ', estimated_hours: '2.5', billable: true })
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_ticket'])
      .to include('is_work_order' => true, 'work_address' => 'Av. Juárez 10', 'estimated_hours' => 2.5,
                  'billable' => true, 'work_order_items' => [])

    post_json(base, case_ticket: { internal: true, case_type_id: orden.id, title: 'Mantenimiento',
                                   estimated_hours: 1 })
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_ticket']).to include('estimated_hours' => 1.0, 'contact_id' => nil)
  end

  it 'editar los datos deja work_order_changed; cerrada ya no se edita' do
    wo = work_order
    patch_json("#{base}/#{wo.id}", case_ticket: { estimated_hours: 3, work_address: 'Bodega 2' })
    expect(response).to have_http_status(:ok)
    expect(wo.case_events.work_order_changed.last.payload.keys).to contain_exactly('estimated_hours', 'work_address')

    wo.transition!('closed', force: true, closure: { actual_hours: 3, received_by: 'Ana' })
    patch_json("#{base}/#{wo.id}", case_ticket: { estimated_hours: 1 })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'materiales: alta, total con y sin costo, edición y baja' do
    wo = work_order
    items = "#{base}/#{wo.id}/work_order_items"
    post_json(items, work_order_item: { description: 'Cable UTP', quantity: 20, unit: 'm', unit_cost: 12.5 })
    expect(response).to have_http_status(:created)
    cable = response.parsed_body['work_order_item']
    expect(cable).to include('total' => 250.0)

    post_json(items, work_order_item: { description: 'Tornillos', quantity: 10 })
    expect(response.parsed_body['work_order_item']['total']).to be_nil

    get "#{base}/#{wo.id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['case_ticket']['work_order_items'].pluck('description')).to eq(['Cable UTP', 'Tornillos'])
    expect(response.parsed_body['case_ticket']['work_order_total']).to eq(250.0)

    patch_json("#{items}/#{cable['id']}", work_order_item: { quantity: 0 })
    expect(response).to have_http_status(:unprocessable_entity)
    delete "#{items}/#{cable['id']}", headers: admin.create_new_auth_token
    expect(wo.work_order_items.count).to eq(1)
  end

  it 'un material no se agrega a un caso que no es orden' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
    post_json("#{base}/#{ticket.id}/work_order_items", work_order_item: { description: 'Cable' })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'cerrar pide horas reales y quién recibió (no causa/solución)' do
    wo = work_order
    patch_json("#{base}/#{wo.id}/transition", status: 'resolved')
    patch_json("#{base}/#{wo.id}/transition", status: 'closed', closure: { received_by: 'Ana' })
    expect(response.parsed_body['error']).to include('horas reales')

    patch_json("#{base}/#{wo.id}/transition", status: 'closed',
                                              closure: { actual_hours: 2.75, received_by: 'Ana López', conformity_note: 'Todo bien' })
    expect(response).to have_http_status(:ok)
    expect(wo.reload).to have_attributes(status: 'closed', received_by: 'Ana López', conformity_note: 'Todo bien',
                                         actual_hours: BigDecimal('2.75'))
    expect(wo.received_at).to be_present
    expect(wo.case_events.last.payload).to include('received_by' => 'Ana López')
  end

  it 'si las horas reales ya estaban en la orden, basta quién recibió' do
    wo = work_order(actual_hours: 4, status: :resolved)
    wo.transition!('closed', closure: { received_by: 'Luis' })
    expect(wo.reload).to have_attributes(status: 'closed', actual_hours: BigDecimal('4'))
  end

  it 'mover a Cerrada en el tablero pide la conformidad' do
    wo = work_order(status: :resolved)
    patch_json("#{base}/#{wo.id}/move", case_type_column_id: column('Cerrada').id)
    expect(response.parsed_body).to include('requires_closure' => true)

    patch_json("#{base}/#{wo.id}/move", case_type_column_id: column('Cerrada').id,
                                        closure: { actual_hours: 1, received_by: 'Ana' })
    expect(response).to have_http_status(:ok)
    expect(wo.reload.status).to eq('closed')
  end

  it 'reabrir borra la conformidad y conserva las horas' do
    wo = work_order
    wo.transition!('closed', force: true, closure: { actual_hours: 2, received_by: 'Ana', conformity_note: 'ok' })
    wo.reopen!(actor: admin, reason: 'Falta un punto de red')
    expect(wo.reload).to have_attributes(received_by: nil, received_at: nil, conformity_note: nil,
                                         actual_hours: BigDecimal('2'))
  end

  it 'el lote no cierra órdenes' do
    wo = work_order(status: :validating)
    post_json("#{base}/bulk", ids: [wo.id], bulk_action: 'transition', status: 'closed')
    expect(response.parsed_body).to include('updated' => 0, 'skipped' => 1)
  end

  # Plan-Clase-Orden-de-Trabajo F2b
  describe 'visitas' do
    def visit_for(order, starts_at)
      CaseMeeting.create!(account: account, case_ticket: order, title: 'Visita', starts_at: starts_at,
                          ends_at: starts_at + 1.hour)
    end

    it 'agendar la primera visita pasa la orden a Programada; después ya no la mueve' do
      wo = work_order(status: :open)
      visit_for(wo, 2.days.from_now)
      expect(wo.reload.status).to eq('assigned')
      expect(wo.case_events.order(:id).last.payload['reason']).to eq('Visita programada')

      wo.update_columns(status: CaseTicket.statuses[:in_progress])
      visit_for(wo, 5.days.from_now)
      expect(wo.reload.status).to eq('in_progress')
    end

    it 'expone la próxima visita y la vencida, y filtra por ellas' do
      soon = work_order(status: :assigned)
      visit_for(soon, 1.day.from_now.change(hour: 10))
      late = work_order(status: :assigned)
      visit_for(late, 2.hours.ago)

      get "#{base}/#{soon.id}", headers: admin.create_new_auth_token
      expect(response.parsed_body['case_ticket']['next_visit_at']).to be_present
      expect(response.parsed_body['case_ticket']['visit_overdue']).to be(false)

      tomorrow = 1.day.from_now.to_date.iso8601
      get base, params: { case_class: 'work_order', visit_from: tomorrow, visit_to: tomorrow },
                headers: admin.create_new_auth_token
      expect(response.parsed_body['case_tickets'].pluck('id')).to eq([soon.id])

      get base, params: { case_class: 'work_order', visit_overdue: 'true' }, headers: admin.create_new_auth_token
      expect(response.parsed_body['case_tickets'].pluck('id')).to eq([late.id])
    end
  end

  it 'filtra por etapa (lista de estados) y por facturable' do
    scheduled = work_order(status: :assigned, billable: true)
    work_order(status: :open)

    get base, params: { case_class: 'work_order', statuses: 'assigned,in_diagnosis' },
              headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([scheduled.id])

    get base, params: { case_class: 'work_order', billable: 'true' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([scheduled.id])
  end

  describe 'crear orden desde otro caso' do
    let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
    let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
    let(:conversation) { create(:conversation, account: account, contact: contact) }

    before { account.enable_features!('case_work_order', 'case_commercial') }

    it 'desde un ticket de Soporte hereda cliente, conversación y asunto, y queda ligada' do
      ticket = CaseTicket.create!(account: account, title: 'No enciende el equipo', description: 'Desde ayer',
                                  contact: contact, conversation: conversation, case_type: soporte)
      post_json("#{base}/#{ticket.id}/work_order", case_type_id: orden.id)

      expect(response).to have_http_status(:created)
      order = CaseTicket.find(response.parsed_body['case_ticket']['id'])
      expect(order).to have_attributes(case_type_id: orden.id, contact_id: contact.id, conversation_id: conversation.id,
                                       title: 'No enciende el equipo', description: 'Desde ayer')
      relation = CaseTicketRelation.last
      expect(relation).to have_attributes(ticket_id: order.id, related_ticket_id: ticket.id,
                                          relation_type: 'work_order_origin')
      expect(ticket.case_events.related.last.payload['related_ticket_id']).to eq(order.id)
    end

    it 'desde una oportunidad solo si está ganada' do
      opp = CaseTicket.create!(account: account, title: 'Instalar 3 equipos', contact: contact, case_type: venta,
                               status: :in_progress)
      post_json("#{base}/#{opp.id}/work_order", case_type_id: orden.id)
      expect(response).to have_http_status(:unprocessable_entity)

      opp.close_with_outcome!(:won, reason_id: CaseOutcomeReason.ensure_defaults_for(account).outcome_won.first.id)
      post_json("#{base}/#{opp.id}/work_order", case_type_id: orden.id)
      expect(response).to have_http_status(:created)
    end

    it 'pide un tipo de orden y el flag activo' do
      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      post_json("#{base}/#{ticket.id}/work_order", case_type_id: soporte.id)
      expect(response.parsed_body['error']).to include('tipo de orden')

      account.disable_features!('case_work_order')
      post_json("#{base}/#{ticket.id}/work_order", case_type_id: orden.id)
      expect(response.parsed_body['error']).to include('no está activa')
    end
  end

  it 'el conteo del aviso rojo depende de la clase pedida' do
    late = work_order(status: :assigned)
    CaseMeeting.create!(account: account, case_ticket: late, title: 'Visita', starts_at: 3.hours.ago,
                        ends_at: 2.hours.ago)
    work_order(status: :assigned)
    venta = CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial)
    CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta,
                       status: :in_progress, expected_close_at: 3.days.ago.to_date)

    get base, params: { case_class: 'work_order' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['meta']['alert_count']).to eq(1)
    get base, params: { case_class: 'commercial' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['meta']['alert_count']).to eq(1)
    get base, params: { case_class: 'support' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['meta']['alert_count']).to eq(0)
  end
end
