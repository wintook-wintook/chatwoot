# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T3: «Documenta…» no se palomea a mano.
RSpec.describe 'Case Tasks API — tarea «Documenta…»' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:ticket)  do
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    CaseTicket.create!(account: account, title: 'Licencias', contact: create(:contact, account: account), case_type: venta)
  end
  let(:column) { venta.case_type_columns.ordered.first }

  it 'rechaza completarla a mano y deja editar lo demás' do
    task = ticket.case_tasks.create!(account: account, title: 'Documenta para pasar a «Ganada»', required: true,
                                     case_type_column: column, documentation_for_column_id: column.id)
    url = "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks/#{task.id}"

    patch url, params: { case_task: { status: 'done' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(task.reload.status).to eq('pending')

    get "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_tasks'].first).to include('documentation' => true, 'required' => true)
  end

  it 'una tarea creada a mano como obligatoria queda en la etapa actual del caso' do
    post "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks",
         params: { case_task: { title: 'Visto bueno', required: true } }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(ticket.case_tasks.find_by(title: 'Visto bueno')).to have_attributes(required: true, case_type_column_id: column.id)
  end
end
