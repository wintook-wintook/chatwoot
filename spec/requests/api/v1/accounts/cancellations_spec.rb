# frozen_string_literal: true

require 'rails_helper'

# Cancelar tareas y tareas agendadas con motivo (y tiempo si ya se trabajó); borrar solo
# errores de captura.
RSpec.describe 'Cancellations' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Mario López') }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: type, conversation: conversation) }
  let(:reasons) { TaskOutcome.ensure_defaults_for(account, purpose: 'cancel') }
  let(:no_longer) { reasons.find_by(label: 'El cliente ya no lo necesita') }
  let(:other) { reasons.find_by(label: 'Otro') }
  let(:base) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}" }

  it 'los motivos de cancelación son un catálogo aparte de los resultados' do
    get "/api/v1/accounts/#{account.id}/task_outcomes", params: { purpose: 'cancel' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['task_outcomes'].pluck('label')).to include('Duplicada', 'Otro')
    get "/api/v1/accounts/#{account.id}/task_outcomes", headers: admin.create_new_auth_token
    expect(response.parsed_body['task_outcomes'].pluck('label')).not_to include('Duplicada')
  end

  it 'cancela una tarea con motivo, sin reporte; queda en la actividad y se puede reabrir' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar')
    post "#{base}/tasks/#{task.id}/cancel", params: { reason_id: no_longer.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_task']).to include('status' => 'cancelled', 'cancel_reason' => 'El cliente ya no lo necesita')
    expect(ticket.case_events.where(event_type: :task_cancelled).last.payload['reason']).to eq('El cliente ya no lo necesita')

    patch "#{base}/tasks/#{task.id}", params: { case_task: { status: 'pending' } }, headers: admin.create_new_auth_token, as: :json
    expect(task.reload).to have_attributes(status: 'pending', cancel_reason: nil, cancelled_at: nil)
  end

  it 'pide motivo, y comentario si es «Otro»' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar')
    post "#{base}/tasks/#{task.id}/cancel", params: {}, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{base}/tasks/#{task.id}/cancel", params: { reason_id: other.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(task.reload).to be_pending
  end

  it 'el tiempo dedicado queda como reporte cerrado; es obligatorio si ya se trabajó' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', starts_at: 2.hours.from_now,
                                  ends_at: 3.hours.from_now, organizer: admin, on_my_way_at: Time.current)
    url = "#{base}/meetings/#{meeting.id}/cancel"
    patch url, params: { reason_id: no_longer.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('tiempo')

    patch url, params: { reason_id: no_longer.id, minutes: 40, notify_client: true }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_meeting']).to include('status' => 'cancelled', 'cancel_reason' => 'El cliente ya no lo necesita')
    expect(response.parsed_body['client_notice']).to eq('sent' => true)
    expect(meeting.task_reports.closed.sole).to have_attributes(minutes: 40)
    expect(conversation.messages.outgoing.last.content).to include('cancelamos «Visita»')
  end

  it 'borrar: quien la creó en las primeras 24 h o un administrador' do
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    mine = ticket.case_tasks.create!(account: account, title: 'Error', requester: agent)
    delete "#{base}/tasks/#{mine.id}", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:no_content)

    old = ticket.case_tasks.create!(account: account, title: 'Vieja', requester: agent, created_at: 2.days.ago)
    delete "#{base}/tasks/#{old.id}", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body['cancel_instead']).to be(true)

    delete "#{base}/tasks/#{old.id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:no_content)
  end
end
