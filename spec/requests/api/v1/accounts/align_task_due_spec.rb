# frozen_string_literal: true

require 'rails_helper'

# «Mover el vencimiento de la tarea» desde su tarea agendada: la tarea vence al final del día
# de la cita (sin hora), en la zona de la cita.
RSpec.describe 'Mover el vencimiento de la tarea' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Caso', requester: admin, origin: :internal) }
  let(:task) { ticket.case_tasks.create!(account: account, title: 'Instalar', due_at: 1.day.from_now.end_of_day) }

  before { allow(Cases::MeetingSyncJob).to receive(:perform_later) }

  it 'la deja vencer al final del día en que termina la cita' do
    ticket.update!(due_at: 30.days.from_now) # el compromiso con el cliente queda después de la cita
    starts = Time.find_zone('America/Mexico_City').parse(3.days.from_now.strftime('%Y-%m-%d 16:00'))
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, case_task: task, title: 'Sesión', organizer: admin,
                                  starts_at: starts, ends_at: starts + 1.hour, time_zone: 'America/Mexico_City')

    patch "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/meetings/#{meeting.id}/align_task_due",
          headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(task.reload.due_at).to be_within(1.second).of(starts.end_of_day)
  end
end
