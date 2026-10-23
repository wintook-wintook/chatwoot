# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F3: métricas de órdenes de trabajo.
RSpec.describe V2::Reports::Cases::WorkOrderBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:tech)    { create(:user, account: account, name: 'Técnica') }
  let(:orden)   { CaseType.create!(account: account, name: 'Visita técnica', color: '#0d9488', case_class: :work_order) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:report)  { described_class.new(account: account, params: {}).build }

  def order(attrs = {})
    CaseTicket.create!({ account: account, title: 'Orden', contact: contact, case_type: orden, assignee: tech,
                         status: :in_progress }.merge(attrs))
  end

  # Orden terminada `finished_ago` atrás, con su última visita `visit_ago` atrás (nil = sin visita).
  def finished(finished_ago:, visit_ago:, **attrs)
    o = order(attrs)
    if visit_ago
      CaseMeeting.create!(account: account, case_ticket: o, title: 'Visita', starts_at: visit_ago.ago,
                          ends_at: visit_ago.ago + 1.hour)
    end
    o.update_columns(status: CaseTicket.statuses[:resolved], resolved_at: finished_ago.ago)
    o
  end

  before do
    finished(finished_ago: 3.days, visit_ago: 2.days, estimated_hours: 2, actual_hours: 3) # a tiempo (antes de la visita)
    finished(finished_ago: 1.day, visit_ago: 4.days, estimated_hours: 2, actual_hours: 1, billable: true) # tarde
    finished(finished_ago: 1.day, visit_ago: nil).update_columns(reopen_count: 1) # sin visita, retrabajo
    order(status: :open) # por programar
    late_visit = order(status: :assigned)
    CaseMeeting.create!(account: account, case_ticket: late_visit, title: 'Visita', starts_at: 3.hours.ago,
                        ends_at: 2.hours.ago)
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte) # no cuenta
  end

  it 'resume lo abierto como foto de hoy' do
    expect(report[:summary]).to include(open_count: 5, to_schedule_count: 1, awaiting_signoff_count: 3,
                                        overdue_visits_count: 1)
  end

  it 'mide cumplimiento, horas y retrabajos de lo terminado' do
    expect(report[:summary]).to include(finished_count: 3, on_time_count: 1, late_count: 1, no_visit_count: 1,
                                        on_time_rate: 50, estimated_hours: 4.0, actual_hours: 4.0,
                                        hours_variance: 0, rework_count: 1, rework_rate: 33, billable_count: 1)
    expect(report[:timing].map { |t| [t[:key], t[:count]] }).to eq([['on_time', 1], ['late', 1], ['no_visit', 1]])
  end

  it 'agrupa por técnico y por tipo, y las etapas por columna' do
    row = report[:by_assignee].first
    expect(row).to include(id: tech.id, name: 'Técnica', finished_count: 3, open_count: 5, on_time_rate: 50)
    expect(report[:by_type].first).to include(name: 'Visita técnica')
    expect(report[:stages].pluck(:label)).to include('Por programar', 'Programada', 'Terminada')
  end

  it 'acota lo terminado al período por la fecha en que se terminó' do
    since = 2.days.ago.to_i.to_s
    scoped = described_class.new(account: account, params: { since: since, until: Time.current.to_i.to_s }).build
    expect(scoped[:summary][:finished_count]).to eq(2)
    expect(scoped[:summary][:open_count]).to eq(5)
  end
end
