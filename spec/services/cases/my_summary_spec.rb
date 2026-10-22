# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — «Mi resumen» (página Inicio).
RSpec.describe Cases::MySummary do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:summary) { described_class.new(user: agent, account: account).call }

  it 'cuenta mis conversaciones abiertas y lista las que esperan respuesta, la más vieja primero' do
    # Chatwoot marca «esperando» a toda conversación nueva hasta la primera respuesta.
    create(:conversation, account: account, assignee: agent, status: :open).update!(waiting_since: nil)
    older = create(:conversation, account: account, assignee: agent, status: :open, waiting_since: 3.hours.ago)
    create(:conversation, account: account, assignee: agent, status: :open, waiting_since: 1.hour.ago)
    create(:conversation, account: account, status: :open, waiting_since: 5.hours.ago) # de otro

    expect(summary[:conversations]).to include(open_count: 3, waiting_count: 2)
    expect(summary[:conversations][:waiting].first[:id]).to eq(older.display_id)
  end

  it 'lista mis casos con SLA en riesgo o vencido' do
    risky = CaseTicket.create!(account: account, title: 'Falla', contact: contact, assignee: agent)
    risky.update_columns(sla_status: CaseTicket.sla_statuses[:overdue]) # rubocop:disable Rails/SkipsModelValidations
    CaseTicket.create!(account: account, title: 'Bien', contact: contact, assignee: agent)

    expect(summary[:cases][:sla_count]).to eq(1)
    expect(summary[:cases][:sla].first).to include(id: risky.id, sla_status: 'overdue')
  end

  it 'lista los casos que ya terminaron las obligatorias de su etapa' do
    venta = CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial)
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    venta.case_type_columns.ordered.first.task_templates.create!(account: account, title: 'Calificar')
    ticket = CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta, assignee: agent)
    ticket.case_tasks.sole.update!(status: :done)

    expect(summary[:cases][:ready].first).to include(id: ticket.id, stage: 'Prospecto', next: 'Calificado')
  end

  it 'cuenta mis tareas hechas de esta semana contra la pasada' do
    ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, assignee: agent)
    task = ticket.case_tasks.create!(account: account, title: 'Hoy')
    Current.user = agent # la firma de completado (quién) sale del usuario actual
    task.update!(status: :done)
    Current.reset

    expect(summary[:week][:this_week][:tasks_done]).to eq(1)
    expect(summary[:week][:last_week][:tasks_done]).to eq(0)
  end
end
