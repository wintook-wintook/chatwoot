# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Proyecto P3: métricas de proyectos.
RSpec.describe V2::Reports::Cases::ProjectBuilder do
  let(:account)  { create(:account) }
  let(:contact)  { create(:contact, account: account) }
  let(:pm)       { create(:user, account: account, name: 'Gerente') }
  let(:proyecto) { CaseType.create!(account: account, name: 'Implementación', color: '#6366f1', case_class: :project) }
  let(:orden)    { CaseType.create!(account: account, name: 'Visita', color: '#0d9488', case_class: :work_order) }
  let(:report)   { described_class.new(account: account, params: {}).build }

  def project(attrs = {})
    CaseTicket.create!({ account: account, title: 'Proyecto', contact: contact, case_type: proyecto, assignee: pm,
                         status: :in_progress }.merge(attrs))
  end

  before do
    # A tiempo: a la mitad del plazo con 60 % de avance.
    project(project_start_on: 10.days.ago.to_date, project_due_on: 10.days.from_now.to_date, progress: 60)
    # En riesgo: a la mitad del plazo con 10 % de avance (40 puntos detrás).
    project(project_start_on: 10.days.ago.to_date, project_due_on: 10.days.from_now.to_date, progress: 10)
    # Atrasado: la fecha objetivo ya pasó.
    late = project(project_start_on: 30.days.ago.to_date, project_due_on: 2.days.ago.to_date, progress: 90,
                   budget_hours: 10)
    child = CaseTicket.create!(account: account, title: 'O1', contact: contact, case_type: orden, actual_hours: 12)
    CaseTicketRelation.create!(account: account, ticket: child, related_ticket: late, relation_type: :project_member)
    late.case_tasks.create!(account: account, title: 'Go live', milestone: true, due_at: 1.day.ago)
    # Sin fechas.
    project
    # Entregado a tiempo y entregado tarde.
    project(project_due_on: 5.days.ago.to_date).update_columns(status: CaseTicket.statuses[:closed],
                                                               closed_at: 6.days.ago)
    project(project_due_on: 5.days.ago.to_date).update_columns(status: CaseTicket.statuses[:closed],
                                                               closed_at: 1.day.ago)
  end

  it 'clasifica la salud de lo abierto contra su plan' do
    expect(report[:health].to_h { |h| [h[:key], h[:count]] })
      .to eq('on_track' => 1, 'at_risk' => 1, 'late' => 1, 'no_dates' => 1)
    expect(report[:summary]).to include(open_count: 4, late_count: 1, at_risk_count: 1, overdue_milestones_count: 1)
  end

  it 'compara horas reales (de las órdenes) contra presupuesto' do
    expect(report[:summary]).to include(budget_hours: 10.0, actual_hours: 12.0, hours_used: 120, over_budget_count: 1)
  end

  it 'mide entregas a tiempo de lo terminado y agrupa por responsable' do
    expect(report[:summary]).to include(finished_count: 2, delivered_on_time_count: 1, delivered_late_count: 1,
                                        on_time_rate: 50)
    expect(report[:by_assignee].first).to include(id: pm.id, name: 'Gerente', open_count: 4, late_count: 1)
    expect(report[:stages].first).to include(label: 'Ejecución', count: 4)
  end
end
