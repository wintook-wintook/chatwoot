# frozen_string_literal: true

require 'rails_helper'

# Tareas con el cliente desde la plataforma: quién la hace, lo que pasó en el portal,
# responderle o regresarla, y el enlace del portal de la organización.
RSpec.describe 'Client tasks API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact, organization: organization, case_type: type) }
  let(:headers) { admin.create_new_auth_token }
  let(:tasks_url) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks" }

  it 'crea una tarea del cliente: sin responsable interno y sin reporte de cierre' do
    post tasks_url, params: { case_task: { title: 'Enviar constancia', audience: 'client', requires_file: true, assignee_id: admin.id } },
                    headers: headers, as: :json
    task = response.parsed_body['case_task']
    expect(task).to include('audience' => 'client', 'requires_file' => true, 'assignee_id' => nil, 'report_required' => false)
  end

  it 'lista lo que pasó en el portal, responde y la regresa a pendiente' do
    task = ticket.case_tasks.create!(account: account, title: 'Probar', audience: :client)
    ClientTasks::Recorder.new(task, contact: contact).finish('Hecho')

    get "#{tasks_url}/#{task.id}/client_entries", headers: headers, as: :json
    expect(response.parsed_body['entries'].pluck('kind')).to eq(['done'])

    post "#{tasks_url}/#{task.id}/client_entries", params: { content: '¿Probaste con RFC genérico?' }, headers: headers, as: :json
    expect(response.parsed_body['entry']).to include('kind' => 'reply', 'by_client' => false)

    post "#{tasks_url}/#{task.id}/client_entries/return", params: { reason: 'Falta el paso 3' }, headers: headers, as: :json
    expect(task.reload).to have_attributes(status: 'pending', completed_by_contact_id: nil)
  end

  it 'regresar pide el porqué' do
    task = ticket.case_tasks.create!(account: account, title: 'Probar', audience: :client)
    post "#{tasks_url}/#{task.id}/client_entries/return", params: { reason: '' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el enlace del portal de la organización: crear, renovar y desactivar' do
    url = "/api/v1/accounts/#{account.id}/client_portal_link"
    get url, params: { organization_id: organization.id }, headers: headers
    expect(response.parsed_body['link']).to be_nil

    post url, params: { organization_id: organization.id }, headers: headers, as: :json
    first = response.parsed_body['link']['url']
    expect(first).to include('/cliente/')

    post "#{url}/renew", params: { organization_id: organization.id }, headers: headers, as: :json
    expect(response.parsed_body['link']['url']).not_to eq(first)

    post "#{url}/disable", params: { organization_id: organization.id }, headers: headers, as: :json
    expect(account.client_portal_links.active.count).to eq(0)
  end
end
