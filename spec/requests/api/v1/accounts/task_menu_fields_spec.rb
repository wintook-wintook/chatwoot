# frozen_string_literal: true

require 'rails_helper'

# El menú de la tarea muestra solo lo que se puede hacer: cuántas tareas agendadas tiene y
# si quien la ve la puede borrar (la creó en las primeras 24 h, o es administrador).
RSpec.describe 'Task menu fields' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: create(:contact, account: account), case_type: type) }

  it 'en el caso: tareas agendadas vivas y si se puede borrar' do
    mine = ticket.case_tasks.create!(account: account, title: 'Mía', requester: agent)
    old = ticket.case_tasks.create!(account: account, title: 'Vieja', requester: agent, created_at: 2.days.ago)
    starts = 1.day.from_now
    2.times do |i|
      CaseMeeting.create!(account: account, case_ticket: ticket, case_task: mine, title: "Sesión #{i}", organizer: agent,
                          starts_at: starts + i.hours, ends_at: starts + i.hours + 30.minutes, status: i.zero? ? :scheduled : :cancelled)
    end

    get "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks", headers: agent.create_new_auth_token
    rows = response.parsed_body['case_tasks'].index_by { |t| t['id'] }
    expect(rows[mine.id]).to include('meetings_count' => 1, 'deletable' => true)
    expect(rows[old.id]).to include('meetings_count' => 0, 'deletable' => false)

    get "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks", headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tasks'].find { |t| t['id'] == old.id }['deletable']).to be(true)
  end

  it 'en la bandeja de tareas también' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar', requester: admin, assignee: admin)
    get "/api/v1/accounts/#{account.id}/case_tasks", params: { scope: 'all' }, headers: admin.create_new_auth_token

    row = response.parsed_body.values.flatten.find { |r| r.is_a?(Hash) && r['id'] == task.id && r['item_type'] == 'task' }
    expect(row).to include('meetings_count' => 0, 'deletable' => true)
  end
end
