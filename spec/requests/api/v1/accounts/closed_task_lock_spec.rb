# frozen_string_literal: true

require 'rails_helper'

# Una tarea concluida o cancelada es de solo lectura: solo se reabre o se le mueve el orden.
RSpec.describe 'Closed task lock' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: create(:contact, account: account), case_type: type) }
  let(:url) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks" }

  it 'cancelada: no se edita ni se concluye; sí se reabre' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar', status: :cancelled, cancel_reason: 'Duplicada')

    patch "#{url}/#{task.id}", params: { case_task: { title: 'Otra' } }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('reábrela')
    patch "#{url}/#{task.id}", params: { case_task: { status: 'done' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    patch "#{url}/#{task.id}", params: { case_task: { status: 'pending' } }, headers: admin.create_new_auth_token, as: :json
    expect(task.reload).to have_attributes(status: 'pending', title: 'Llamar')
  end

  it 'concluida: solo reabrir o mover de orden' do
    task = ticket.case_tasks.create!(account: account, title: 'Instalar', status: :done)

    patch "#{url}/#{task.id}", params: { case_task: { assignee_id: admin.id } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    patch "#{url}/#{task.id}", params: { case_task: { position: 3 } }, headers: admin.create_new_auth_token, as: :json
    expect(task.reload.position).to eq(3)
  end

  it 'tarea sin caso: igual' do
    task = CaseTask.create!(account: account, title: 'Cobrar', assignee: admin, requester: admin, status: :done)
    patch "/api/v1/accounts/#{account.id}/quick_tasks/#{task.id}", params: { title: 'Otra' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    patch "/api/v1/accounts/#{account.id}/quick_tasks/#{task.id}", params: { status: 'pending' }, headers: admin.create_new_auth_token, as: :json
    expect(task.reload).to be_pending
  end
end
