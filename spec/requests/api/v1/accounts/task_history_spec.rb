# frozen_string_literal: true

require 'rails_helper'

# Historial de la tarea: notas, reportes (avances y cierre), sus tareas agendadas y cambios,
# con caso o sin él.
RSpec.describe 'Historial de la tarea' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }
  let(:contact) { create(:contact, account: account) }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, title: 'Caso', assignee: agent) }
  let(:task) { ticket.case_tasks.create!(account: account, title: 'Instalar', assignee: agent, requester: agent, estimated_minutes: 90) }
  let(:url) { "/api/v1/accounts/#{account.id}/case_tasks/#{task.id}/history" }

  before { allow(Cases::MeetingSyncJob).to receive(:perform_later) }

  def progress(item, minutes)
    report = TaskReport.build_for(item, user: agent, content: 'Avancé', minutes: minutes, progress: true)
    report.save!
    report.close!
    report
  end

  it 'con caso: sus notas, avances y lo de sus tareas agendadas; no lo de otras tareas' do
    other = ticket.case_tasks.create!(account: account, title: 'Otra')
    ticket.add_internal_note!(content: 'Nota de la tarea', actor: agent, case_task: task)
    ticket.add_internal_note!(content: 'Nota de otra', actor: agent, case_task: other)
    progress(task, 30)
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, case_task: task, title: 'Sesión', organizer: agent,
                                  starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    ticket.case_events.create!(account: account, event_type: :meeting_scheduled, origin: :agent, actor: agent,
                               payload: { meeting_id: meeting.id, title: 'Sesión' })

    get url, headers: headers

    body = response.parsed_body
    expect(body['task']).to include('title' => 'Instalar', 'estimated_minutes' => 90, 'reported_minutes' => 30)
    types = body['items'].pluck('event_type')
    expect(types).to include('internal_note', 'task_reported', 'meeting_scheduled', 'task_created')
    expect(body['items'].to_s).not_to include('Nota de otra')
    expect(body['items'].find { |i| i['event_type'] == 'task_reported' }['report']).to include('minutes' => 30, 'progress' => true)
  end

  it 'sin caso: se arma con sus reportes y su cierre' do
    quick = CaseTask.create!(account: account, title: 'Cobrar', contact: contact, assignee: agent, requester: agent)
    progress(quick, 15)
    quick.update!(status: :done)

    get "/api/v1/accounts/#{account.id}/case_tasks/#{quick.id}/history", headers: headers

    expect(response.parsed_body['items'].pluck('event_type')).to eq(%w[task_completed task_reported task_created])
  end
end
