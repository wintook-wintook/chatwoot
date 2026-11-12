# frozen_string_literal: true

require 'rails_helper'

# Dali — reportar avance de una tarea: propone y, al confirmar, un reporte de avance (la tarea
# sigue pendiente y no entra como nota).
RSpec.describe Assistant::ProgressTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:contact) { create(:contact, account: account) }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact) }
  let(:task) { ticket.case_tasks.create!(account: account, title: 'Llamar al proveedor', estimated_minutes: 45) }

  before { Current.user = user }
  after { Current.user = nil }

  it 'propone con lo dictado y el tiempo; al confirmar queda el avance' do
    proposal = tools.call('propose_task_progress', { 'id' => task.id, 'notes' => 'Ya confirmó precio', 'minutes' => 20 })[:proposal]
    expect(proposal['type']).to eq('task_progress')
    expect(proposal['payload']).to include('id' => task.id, 'minutes' => 20)

    result = executor.call('task_progress', proposal['payload'])
    expect(result['label']).to include('Avance')
    expect(task.reload).to be_pending
    expect(task.task_reports.sole).to have_attributes(progress: true, minutes: 20, content: 'Ya confirmó precio')
    expect(ticket.case_events.where(event_type: :task_reported).sole.payload).to include('kind' => 'progress', 'via' => 'assistant')
    expect(ticket.case_events.where(event_type: :internal_note)).to be_empty
  end

  it 'sin minutos propone lo que falta de lo estimado; no de una tarea concluida' do
    proposal = tools.call('propose_task_progress', { 'id' => task.id, 'notes' => 'Avancé' })[:proposal]
    expect(proposal['payload']['minutes']).to eq(45)

    task.update_columns(status: CaseTask.statuses[:done]) # rubocop:disable Rails/SkipsModelValidations
    expect(tools.call('propose_task_progress', { 'id' => task.id, 'notes' => 'x' })[:result][:error]).to be_present
  end

  it 'lee el historial de la tarea: tiempo y lo que pasó' do
    executor.call('task_progress', { 'id' => task.id, 'notes' => 'Llamé al proveedor', 'minutes' => 20 })
    result = tools.call('task_history', { 'id' => task.id })[:result]

    expect(result).to include(title: 'Llamar al proveedor', status: 'pending', reported_minutes: 20, estimated_minutes: 45)
    expect(result[:history].first).to include(what: 'progress', minutes: 20)
    expect(result[:history].first[:text]).to include('Llamé al proveedor')
  end
end
