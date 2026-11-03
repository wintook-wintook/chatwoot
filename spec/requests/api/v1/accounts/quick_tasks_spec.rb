# frozen_string_literal: true

require 'rails_helper'

# Plan-Agenda — captura rápida: tarea sin caso, que nunca va a Google.
RSpec.describe 'Quick Tasks API' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:tecnico) { create(:user, account: account, role: :agent) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:base) { "/api/v1/accounts/#{account.id}/quick_tasks" }
  let(:headers) { agent.create_new_auth_token }

  def create_task(params)
    post base, params: params, headers: headers, as: :json
    CaseTask.find_by(id: response.parsed_body.dig('case_task', 'id'))
  end

  def inbox(params)
    get "/api/v1/accounts/#{account.id}/case_tasks", params: params, headers: headers
    response.parsed_body['case_tasks'].pluck('title')
  end

  it 'sin nada más que el título: es del que la crea y sale en su Mi día' do
    task = create_task(title: 'Comprar tóner', planned_on: Time.zone.today)

    expect(task).to have_attributes(assignee_id: agent.id, requester_id: agent.id, contact_id: nil, organization_id: nil, case_ticket_id: nil)
    expect(inbox(mode: 'my_day', day: Time.zone.today.iso8601)).to eq(['Comprar tóner'])
  end

  it 'guarda vencimiento y fecha programada, y se la puede poner a otra persona' do
    due = 3.days.from_now.change(usec: 0)
    task = create_task(title: 'Revisar', due_at: due, planned_on: 1.day.from_now.to_date, assignee_id: tecnico.id)

    expect(task).to have_attributes(assignee_id: tecnico.id, requester_id: agent.id, due_at: due, planned_on: 1.day.from_now.to_date)
  end

  it 'con contacto toma su organización y sale en las dos fichas' do
    task = create_task(title: 'Llamar', contact_id: contact.id)

    expect(task.organization_id).to eq(organization.id)
    expect(inbox(contact_id: contact.id, assignee_id: 'all')).to eq(['Llamar'])
    expect(inbox(organization_id: organization.id, assignee_id: 'all')).to eq(['Llamar'])
  end

  it 'puede ir solo con organización' do
    task = create_task(title: 'Visitar', organization_id: organization.id)

    expect(task).to have_attributes(contact_id: nil, organization_id: organization.id)
  end

  it 'no acepta contacto ni organización de otra cuenta, ni título vacío' do
    create_task(title: 'X', contact_id: create(:contact).id)
    expect(response).to have_http_status(:not_found)
    create_task(title: '')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'nunca toca Google' do
    allow(GoogleCalendarService).to receive(:new)
    create_task(title: 'Local')

    expect(GoogleCalendarService).not_to have_received(:new)
  end

  it 'se completa y se borra' do
    task = create_task(title: 'Hacer')
    post "/api/v1/accounts/#{account.id}/task_reports", params: { item_type: 'task', item_id: task.id, content: 'Listo' }, headers: headers

    patch "#{base}/#{task.id}", params: { status: 'done' }, headers: headers, as: :json
    expect(task.reload).to be_done
    delete "#{base}/#{task.id}", headers: headers
    expect(CaseTask.exists?(task.id)).to be(false)
  end

  it 'con caso no se toca por aquí' do
    ticket = CaseTicket.create!(account: account, contact: contact, title: 'Caso')
    task = CaseTask.create!(account: account, case_ticket: ticket, title: 'Del caso')

    delete "#{base}/#{task.id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it 'con Agenda en «solo lo suyo» no toca la de otro' do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    role.update!(areas: role.areas.merge('agenda' => 'own'))
    account.account_users.find_by(user: agent).update!(access_role: role)
    ajena = CaseTask.create!(account: account, title: 'Ajena', assignee: tecnico)

    patch "#{base}/#{ajena.id}", params: { title: 'Mía' }, headers: headers, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
