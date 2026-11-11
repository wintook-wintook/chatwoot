# frozen_string_literal: true

require 'rails_helper'

# Tarea ↔ tarea agendada (Cases::Conversion): la tarea pasa a la agenda con día y hora, y la
# tarea agendada sale de la agenda y queda como tarea. El tiempo reportado no se pierde.
RSpec.describe 'Conversions' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Mario López') }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: type, conversation: conversation) }
  let(:base) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}" }
  let(:starts) { 2.days.from_now.change(hour: 10) }

  before { allow(Cases::MeetingSyncJob).to receive(:perform_later) }

  it 'una tarea pasa a la agenda: desaparece, la agendada hereda sus datos y su tiempo' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar a Mario', description: 'Lo de la factura',
                                     assignee: admin, estimated_minutes: 45)
    report = TaskReport.build_for(task, user: admin, minutes: 20, content: 'avance')
    report.save!

    post "#{base}/tasks/#{task.id}/schedule", params: { starts_at: starts.iso8601 }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['mode']).to eq('converted')

    meeting = ticket.case_meetings.sole
    expect(meeting).to have_attributes(title: 'Llamar a Mario', description: 'Lo de la factura', organizer_id: admin.id,
                                       ends_at: starts + 45.minutes, case_task_id: nil)
    expect(CaseTask.exists?(task.id)).to be(false)
    expect(report.reload).to have_attributes(case_task_id: nil, case_meeting_id: meeting.id)
    expect(ticket.case_events.pluck(:event_type)).to include('task_converted')
    expect(ticket.case_events.pluck(:event_type)).not_to include('task_deleted')
    expect(Cases::MeetingSyncJob).to have_received(:perform_later).with(meeting.id, 'create')
  end

  it 'la obligatoria (o del cliente) no desaparece: se agenda una sesión ligada' do
    task = ticket.case_tasks.create!(account: account, title: 'Firmar', required: true)
    post "#{base}/tasks/#{task.id}/schedule", params: { starts_at: starts.iso8601 }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['mode']).to eq('linked')
    expect(task.reload).to be_pending
    expect(ticket.case_meetings.sole.case_task_id).to eq(task.id)
  end

  it '«que la tarea se quede»: solo una sesión ligada' do
    task = ticket.case_tasks.create!(account: account, title: 'Capacitar')
    post "#{base}/tasks/#{task.id}/schedule", params: { starts_at: starts.iso8601, keep_task: true },
                                              headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['mode']).to eq('linked')
    expect(ticket.case_meetings.sole.case_task_id).to eq(task.id)
  end

  it 'pide día y hora, y solo pendientes' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar')
    post "#{base}/tasks/#{task.id}/schedule", params: {}, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('día y la hora')

    task.update!(status: :cancelled)
    post "#{base}/tasks/#{task.id}/schedule", params: { starts_at: starts.iso8601 }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'una tarea agendada pasa a tarea: sale de la agenda y de Google, con su tiempo y aviso al cliente' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', description: 'Revisar equipo',
                                  starts_at: starts, ends_at: starts + 90.minutes, organizer: admin)
    report = TaskReport.build_for(meeting, user: admin, minutes: 15, content: 'llamada previa')
    report.save!

    post "#{base}/meetings/#{meeting.id}/to_task", params: { notify_client: true }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('mode' => 'converted', 'client_notice' => { 'sent' => true })

    task = ticket.case_tasks.sole
    expect(task).to have_attributes(title: 'Visita', description: 'Revisar equipo', assignee_id: admin.id, estimated_minutes: 90)
    expect(task.due_at).to be_within(1.second).of(starts.end_of_day) # sin hora: vence al final del día
    expect(CaseMeeting.exists?(meeting.id)).to be(false)
    expect(report.reload).to have_attributes(case_meeting_id: nil, case_task_id: task.id)
    expect(conversation.messages.outgoing.last.content).to include('quitamos de la agenda «Visita»')
    expect(ticket.case_events.where(event_type: :task_converted).last.payload['direction']).to eq('to_task')
  end

  it 'la sesión de una tarea no crea otra: queda la tarea' do
    task = ticket.case_tasks.create!(account: account, title: 'Implementar')
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, case_task: task, title: 'Sesión',
                                  starts_at: starts, ends_at: starts + 1.hour, organizer: admin)
    post "#{base}/meetings/#{meeting.id}/to_task", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('mode' => 'linked')
    expect(response.parsed_body['task']['id']).to eq(task.id)
    expect(ticket.case_tasks.count).to eq(1)
  end

  it 'no se pasa a tarea si ya salió a la visita' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', starts_at: starts,
                                  ends_at: starts + 1.hour, organizer: admin, on_my_way_at: Time.current)
    post "#{base}/meetings/#{meeting.id}/to_task", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(meeting.reload).to be_scheduled
  end

  it 'sin caso: la tarea rápida pasa a la agenda con su contacto, y de regreso' do
    task = CaseTask.create!(account: account, title: 'Pasar a cobrar', contact: contact, assignee: admin, requester: admin)
    post "/api/v1/accounts/#{account.id}/quick_tasks/#{task.id}/schedule", params: { starts_at: starts.iso8601 },
                                                                           headers: admin.create_new_auth_token, as: :json
    meeting = account.case_meetings.find(response.parsed_body['meeting']['id'])
    expect(meeting).to have_attributes(contact_id: contact.id, case_ticket_id: nil)

    post "/api/v1/accounts/#{account.id}/agenda_items/#{meeting.id}/to_task", headers: admin.create_new_auth_token, as: :json
    back = account.case_tasks.find(response.parsed_body['task']['id'])
    expect(back).to have_attributes(title: 'Pasar a cobrar', contact_id: contact.id, case_ticket_id: nil)
  end
end
