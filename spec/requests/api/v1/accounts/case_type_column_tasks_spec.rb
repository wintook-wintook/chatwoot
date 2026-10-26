# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T1: tareas plantilla de cada etapa.
RSpec.describe 'Case Type Column Tasks API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:column)  do
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    venta.case_type_columns.ordered.first
  end
  let(:base) { "/api/v1/accounts/#{account.id}/case_types/#{venta.id}/columns/#{column.id}/tasks" }

  def json(verb, url, user: admin, params: {})
    send(verb, url, params: params, headers: user.create_new_auth_token, as: :json)
  end

  it 'crea una tarea con los valores por defecto: obligatoria, prioridad media y del responsable del caso' do
    json(:post, base, params: { task: { title: 'Armar cotización', due_after_hours: 24 } })

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['task']).to include('title' => 'Armar cotización', 'required' => true,
                                                    'priority' => 'medium', 'assignee_mode' => 'case_assignee',
                                                    'due_after_hours' => 24, 'position' => 0)
  end

  it 'lista las tareas de la etapa en orden y las cuenta en la columna' do
    %w[Uno Dos].each { |t| json(:post, base, params: { task: { title: t } }) }
    json(:get, base)
    expect(response.parsed_body['tasks'].pluck('title')).to eq(%w[Uno Dos])

    json(:get, "/api/v1/accounts/#{account.id}/case_types/#{venta.id}/columns")
    first = response.parsed_body['case_type_columns'].find { |c| c['id'] == column.id }
    expect(first).to include('tasks_count' => 2, 'advance_mode' => 'suggest')
  end

  it 'reordena la lista' do
    ids = %w[Uno Dos Tres].map do |t|
      json(:post, base, params: { task: { title: t } })
      response.parsed_body['task']['id']
    end
    json(:put, "#{base}/reorder", params: { ids: ids.reverse })

    expect(response.parsed_body['tasks'].pluck('title')).to eq(%w[Tres Dos Uno])
  end

  it 'pide la persona cuando la tarea es de una persona fija, y la acepta si es de la cuenta' do
    json(:post, base, params: { task: { title: 'Revisar', assignee_mode: 'user' } })
    expect(response).to have_http_status(:unprocessable_entity)

    json(:post, base, params: { task: { title: 'Revisar', assignee_mode: 'user', assignee_id: agent.id } })
    expect(response).to have_http_status(:created)
  end

  it 'rechaza una prioridad que no existe' do
    json(:post, base, params: { task: { title: 'X', priority: 'altisima' } })

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'edita y borra' do
    json(:post, base, params: { task: { title: 'Viejo' } })
    id = response.parsed_body['task']['id']
    json(:patch, "#{base}/#{id}", params: { task: { title: 'Nuevo', required: false } })
    expect(response.parsed_body['task']).to include('title' => 'Nuevo', 'required' => false)

    json(:delete, "#{base}/#{id}")
    expect(column.task_templates.count).to eq(0)
  end

  it 'un agente puede ver la plantilla pero no cambiarla' do
    json(:post, base, user: agent, params: { task: { title: 'X' } })
    expect(response).to have_http_status(:forbidden) # Plan-Roles-Permisos: Ajustes cerrado por rol

    json(:get, base, user: agent)
    expect(response).to have_http_status(:ok)
  end

  it 'guarda el modo de avance de la etapa' do
    json(:patch, "/api/v1/accounts/#{account.id}/case_types/#{venta.id}/columns/#{column.id}",
         params: { case_type_column: { advance_mode: 'automatic' } })

    expect(column.reload.advance_mode).to eq('automatic')
  end

  it 'al reemplazar las columnas no se pierden las tareas de una etapa que sigue' do
    json(:post, base, params: { task: { title: 'Sigue' } })
    columns = venta.case_type_columns.ordered.map do |c|
      { id: c.id, label: c.label, color: c.color, position: c.position, statuses: c.statuses,
        outcome: c.outcome, probability: c.probability }
    end
    json(:put, "/api/v1/accounts/#{account.id}/case_types/#{venta.id}/columns/replace", params: { columns: columns })

    expect(response).to have_http_status(:ok)
    expect(column.reload.task_templates.pluck(:title)).to eq(['Sigue'])
  end
end
