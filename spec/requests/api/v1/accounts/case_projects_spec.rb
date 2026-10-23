# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Proyecto P1: la clase, sus fases, sus datos, el aviso
# de atrasados y el cierre con resumen opcional.
RSpec.describe 'Case Tickets API — proyectos' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:proyecto) { CaseType.create!(account: account, name: 'Implementación', color: '#6366f1', case_class: :project) }
  let(:base) { "/api/v1/accounts/#{account.id}/case_tickets" }

  def project(attrs = {})
    CaseTicket.create!({ account: account, title: 'ERP sucursales', contact: contact, case_type: proyecto,
                         status: :in_progress }.merge(attrs))
  end

  def json(verb, url, params = {})
    public_send(verb, url, params: params, headers: admin.create_new_auth_token, as: :json)
  end

  it 'se ofrece con su flag, nace con sus fases, sin SLA ni portal, y el bot sí lo ve' do
    json(:post, "/api/v1/accounts/#{account.id}/case_types", case_type: { name: 'Obra', color: '#6366f1', case_class: 'project' })
    expect(response).to have_http_status(:unprocessable_entity)
    account.enable_features!('case_project')
    json(:post, "/api/v1/accounts/#{account.id}/case_types", case_type: { name: 'Obra', color: '#6366f1', case_class: 'project' })
    expect(response).to have_http_status(:created)

    expect(proyecto.case_type_columns.ordered.pluck(:label))
      .to eq(%w[Planeación Ejecución Pausado Entrega Cerrado Cancelado])
    p = project
    expect(p.resolution_time_target).to be_nil
    expect(account.case_tickets.with_capability(:bot_status)).to include(p)
    expect(account.case_tickets.with_capability(:portal)).not_to include(p)
  end

  it 'crea y edita sus datos (presupuesto en la moneda de la cuenta) y deja project_changed' do
    json(:post, base, case_ticket: { contact_id: contact.id, case_type_id: proyecto.id, title: 'ERP',
                                     project_start_on: '2026-11-01', project_due_on: '2027-01-31',
                                     budget_hours: 120, budget_amount: '85000' })
    expect(response).to have_http_status(:created)
    body = response.parsed_body['case_ticket']
    expect(body).to include('is_project' => true, 'project_due_on' => '2027-01-31', 'budget_hours' => 120.0,
                            'budget_amount' => 85_000.0, 'currency' => 'MXN')

    json(:patch, "#{base}/#{body['id']}", case_ticket: { progress: 40 })
    expect(CaseTicket.find(body['id']).case_events.project_changed.last.payload.keys).to eq(['progress'])

    json(:patch, "#{base}/#{body['id']}", case_ticket: { progress: 140 })
    expect(response).to have_http_status(:unprocessable_entity)
    json(:patch, "#{base}/#{body['id']}", case_ticket: { project_due_on: '2026-10-01' })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'atrasado = abierto con la fecha objetivo pasada: JSON, aviso y filtro por fecha' do
    late = project(project_due_on: 3.days.ago.to_date)
    project(project_due_on: 1.month.from_now.to_date)
    project(project_due_on: 3.days.ago.to_date, status: :resolved)

    json(:get, "#{base}/#{late.id}")
    expect(response.parsed_body['case_ticket']['project_overdue']).to be(true)

    json(:get, base, case_class: 'project')
    expect(response.parsed_body['meta']['alert_count']).to eq(1)

    json(:get, base, case_class: 'project', project_due_to: Date.current.iso8601, status: 'pending')
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([late.id])
  end

  it 'se cierra sin causa/solución, con un resumen opcional' do
    p = project(status: :resolved)
    json(:patch, "#{base}/#{p.id}/transition", status: 'closed', closure: { closure_solution: 'Entregado en sitio' })
    expect(response).to have_http_status(:ok)
    expect(p.reload).to have_attributes(status: 'closed', closure_solution: 'Entregado en sitio')
  end

  # Plan-Clase-Proyecto P2
  describe 'casos dentro del proyecto, hitos y avance' do
    let(:orden)   { CaseType.create!(account: account, name: 'Visita', color: '#0d9488', case_class: :work_order) }
    let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
    let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
    let(:children_url) { ->(p) { "#{base}/#{p.id}/project_children" } }

    it 'crea una orden dentro del proyecto con el cliente del proyecto' do
      p = project
      json(:post, children_url.call(p), case_type_id: orden.id, title: 'Instalar servidor')
      expect(response).to have_http_status(:created)
      created = CaseTicket.find(response.parsed_body['project_child']['id'])
      expect(created).to have_attributes(case_type_id: orden.id, contact_id: contact.id, title: 'Instalar servidor')
      expect(created.parent_project).to eq(p)
    end

    it 'liga un ticket existente, solo a un proyecto, y se puede quitar' do
      p = project
      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      json(:post, children_url.call(p), ticket_id: ticket.id)
      expect(response).to have_http_status(:created)
      json(:get, children_url.call(p))
      expect(response.parsed_body['project_children'].pluck('id')).to eq([ticket.id])

      other = project(title: 'Otro')
      json(:post, children_url.call(other), ticket_id: ticket.id)
      expect(response.parsed_body['error']).to include('ya pertenece')

      json(:delete, "#{children_url.call(p)}/#{ticket.id}")
      expect(response).to have_http_status(:no_content)
      expect(ticket.reload.parent_project).to be_nil
    end

    it 'no acepta oportunidades ni proyectos como hijos' do
      p = project
      opp = CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta)
      json(:post, children_url.call(p), ticket_id: opp.id)
      expect(response.parsed_body['error']).to include('Solo órdenes')
      json(:post, children_url.call(p), case_type_id: venta.id)
      expect(response.parsed_body['error']).to include('Elige un tipo')
    end

    it 'avance automático con hijos e hitos (los cancelados no cuentan) y horas de las órdenes' do
      p = project(progress: 10)
      expect(p.project_progress_summary).to include(progress: 10, progress_auto: false)

      done = CaseTicket.create!(account: account, title: 'O1', contact: contact, case_type: orden, status: :closed,
                                actual_hours: 3)
      open_one = CaseTicket.create!(account: account, title: 'O2', contact: contact, case_type: orden, actual_hours: 1)
      cancelled = CaseTicket.create!(account: account, title: 'O3', contact: contact, case_type: orden, status: :cancelled)
      [done, open_one, cancelled].each do |c|
        CaseTicketRelation.create!(account: account, ticket: c, related_ticket: p, relation_type: :project_member)
      end
      p.case_tasks.create!(account: account, title: 'Kickoff', milestone: true, status: :done)
      p.case_tasks.create!(account: account, title: 'Go live', milestone: true)
      p.case_tasks.create!(account: account, title: 'Nota suelta', status: :done) # no es hito

      json(:get, "#{base}/#{p.id}")
      body = response.parsed_body['case_ticket']
      expect(body).to include('progress' => 50, 'progress_manual' => 10)
      expect(body['project_summary']).to include('progress_auto' => true, 'children_total' => 2, 'children_done' => 1,
                                                 'milestones_total' => 2, 'milestones_done' => 1, 'actual_hours' => 4.0)
    end

    it 'la tarea guarda y expone la casilla de hito' do
      p = project
      json(:post, "#{base}/#{p.id}/tasks", case_task: { title: 'Entrega fase 1', milestone: true })
      expect(response.parsed_body['case_task']['milestone']).to be(true)
    end

    it 'crear proyecto desde una oportunidad ganada (no desde un ticket) y queda ligado' do
      account.enable_features!('case_project', 'case_commercial')
      opp = CaseTicket.create!(account: account, title: 'ERP 3 sucursales', contact: contact, case_type: venta,
                               status: :in_progress)
      json(:post, "#{base}/#{opp.id}/project", case_type_id: proyecto.id)
      expect(response).to have_http_status(:unprocessable_entity)

      opp.close_with_outcome!(:won, reason_id: CaseOutcomeReason.ensure_defaults_for(account).outcome_won.first.id)
      json(:post, "#{base}/#{opp.id}/project", case_type_id: proyecto.id)
      expect(response).to have_http_status(:created)
      created = CaseTicket.find(response.parsed_body['case_ticket']['id'])
      expect(created).to have_attributes(case_type_id: proyecto.id, title: 'ERP 3 sucursales', contact_id: contact.id)
      expect(CaseTicketRelation.last).to have_attributes(ticket_id: created.id, related_ticket_id: opp.id,
                                                         relation_type: 'project_origin')

      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      json(:post, "#{base}/#{ticket.id}/project", case_type_id: proyecto.id)
      expect(response.parsed_body['error']).to include('oportunidad ganada')
    end
  end

  it 'línea de tiempo: hitos y casos con fecha, ordenados, con inicio, objetivo y hoy' do
    orden = CaseType.create!(account: account, name: 'Visita', color: '#0d9488', case_class: :work_order)
    p = project(project_start_on: 5.days.ago.to_date, project_due_on: 20.days.from_now.to_date)
    p.case_tasks.create!(account: account, title: 'Kickoff', milestone: true, due_at: 3.days.ago, status: :done)
    p.case_tasks.create!(account: account, title: 'Sin fecha', milestone: true)
    child = CaseTicket.create!(account: account, title: 'Instalar', contact: contact, case_type: orden,
                               due_at: 7.days.from_now)
    CaseTicketRelation.create!(account: account, ticket: child, related_ticket: p, relation_type: :project_member)

    json(:get, "#{base}/#{p.id}/project_children/timeline")
    body = response.parsed_body
    expect(body).to include('start_on' => 5.days.ago.to_date.iso8601, 'due_on' => 20.days.from_now.to_date.iso8601)
    expect(body['items'].map { |i| [i['kind'], i['title']] }).to eq([%w[milestone Kickoff], %w[case Instalar]])
    expect(body['items'].first).to include('done' => true, 'overdue' => false)
  end
end
