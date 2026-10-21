# frozen_string_literal: true

require 'rails_helper'

# Plan-Bandeja-Prioridad F1 — puntaje de urgencia de las tareas («Mi día»).
RSpec.describe Cases::TaskPriorityScore do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:support) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:project_type) { CaseType.create!(account: account, name: 'Implementación', color: '#6366f1', case_class: :project) }
  let(:work_order_type) { CaseType.create!(account: account, name: 'Instalación', color: '#0d9488', case_class: :work_order) }
  let(:now) { Time.zone.parse('2026-10-21 10:00') }

  def ticket(type = support, **attrs)
    CaseTicket.create!(account: account, contact: contact, case_type: type, title: 'Caso', **attrs)
  end

  def task(case_ticket, **attrs)
    CaseTask.create!({ account: account, case_ticket: case_ticket, title: 'Tarea', priority: :low,
                       created_at: now }.merge(attrs))
  end

  def result_for(the_task)
    described_class.new(CaseTask.where(id: the_task.id).includes(case_ticket: :case_type), account: account, now: now)
                   .call[the_task.id]
  end

  def reason_keys(the_task)
    result_for(the_task)[:reasons].pluck(:key)
  end

  it 'suma vencimiento con atraso por día (tope) y prioridad' do
    late = task(ticket, due_at: now - 2.days, priority: :urgent)

    result = result_for(late)

    expect(result[:reasons]).to include(include(key: 'overdue', points: 46, days: 2), include(key: 'priority_urgent', points: 30))
    expect(result[:score]).to eq(76)
  end

  it 'el atraso por día no pasa del tope' do
    expect(result_for(task(ticket, due_at: now - 30.days))[:reasons]).to include(include(key: 'overdue', points: 60))
  end

  it 'vence hoy, mañana y en la semana' do
    expect(reason_keys(task(ticket, due_at: now + 2.hours))).to include('due_today')
    expect(reason_keys(task(ticket, due_at: now + 1.day))).to include('due_tomorrow')
    expect(reason_keys(task(ticket, due_at: now + 5.days))).to include('due_week')
  end

  it 'proyecto atrasado pesa más que SLA vencido, también en un caso dentro del proyecto' do
    project = ticket(project_type, project_due_on: now.to_date - 1)
    child = ticket
    CaseTicketRelation.create!(account: account, ticket: child, related_ticket: project, relation_type: :project_member)
    child.update_columns(sla_status: CaseTicket.sla_statuses[:overdue]) # rubocop:disable Rails/SkipsModelValidations

    result = result_for(task(child))

    points = result[:reasons].to_h { |r| [r[:key], r[:points]] }
    expect(points['project_overdue']).to be > points['sla_overdue']
  end

  it 'hito del proyecto' do
    project = ticket(project_type, project_due_on: now.to_date + 60)
    expect(reason_keys(task(project, milestone: true))).to include('milestone')
  end

  it 'el SLA solo cuenta en clases con SLA' do
    order = ticket(work_order_type)
    order.update_columns(sla_status: CaseTicket.sla_statuses[:overdue]) # rubocop:disable Rails/SkipsModelValidations
    expect(reason_keys(task(order))).not_to include('sla_overdue')
  end

  it 'visita vencida en una orden' do
    order = ticket(work_order_type)
    CaseMeeting.create!(account: account, case_ticket: order, title: 'Visita', starts_at: now - 3.hours,
                        ends_at: now - 2.hours, status: :scheduled)
    expect(reason_keys(task(order))).to include('visit_overdue')
  end

  it 'caso en espera resta' do
    waiting = ticket
    waiting.update_columns(status: CaseTicket.statuses[:waiting_on_customer]) # rubocop:disable Rails/SkipsModelValidations
    expect(result_for(task(waiting))[:reasons]).to include(include(key: 'waiting', points: -15))
  end

  it 'programada para un día que ya pasó suma puntos; hoy o después, no' do
    expect(result_for(task(ticket, planned_on: now.to_date - 2))[:reasons])
      .to include(include(key: 'planned_missed', points: 20, date: (now.to_date - 2).iso8601))
    expect(reason_keys(task(ticket, planned_on: now.to_date))).not_to include('planned_missed')
  end

  it 'usa los pesos de la cuenta (F3)' do
    CaseSetting.for_account(account).update!(task_priority_weights: { 'priority_urgent' => 80 })
    expect(result_for(task(ticket, priority: :urgent))[:reasons]).to include(include(key: 'priority_urgent', points: 80))
  end

  it 'un peso en 0 no deja motivo' do
    CaseSetting.for_account(account).update!(task_priority_weights: { 'priority_low' => 0, 'priority_medium' => 0 })
    expect(reason_keys(task(ticket, priority: :medium))).not_to include('priority_medium')
  end

  it 'antigüedad: un punto por día con tope' do
    old = task(ticket, created_at: now - 40.days)
    expect(result_for(old)[:reasons]).to include(include(key: 'age', points: 10))
  end
end
