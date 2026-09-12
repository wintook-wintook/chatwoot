# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — bandeja de tareas a nivel cuenta: `item_type` fusiona tareas
# (CaseTask) y reuniones agendadas (CaseMeeting) en un solo feed, o filtra a
# solo uno de los dos.
RSpec.describe 'Case Tasks Index API — item_type (tareas + reuniones agendadas)' do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent, name: 'Otro Agente') }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Caso') }

  def crear_tarea(due_at:, assignee: agent, status: 'pending')
    CaseTask.create!(account: account, case_ticket: ticket, title: 'Tarea', due_at: due_at,
                     assignee: assignee, status: status)
  end

  def crear_reunion(starts_at:, organizer: agent, status: 'scheduled')
    CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Reunión',
                        starts_at: starts_at, ends_at: starts_at + 30.minutes,
                        organizer: organizer, status: status)
  end

  def get_bandeja(params = {})
    get "/api/v1/accounts/#{account.id}/case_tasks",
        params: { assignee_id: agent.id, status: 'all' }.merge(params),
        headers: agent.create_new_auth_token, as: :json
  end

  it 'item_type=task se comporta igual que antes (solo tareas)' do
    crear_tarea(due_at: 1.day.from_now)
    crear_reunion(starts_at: 1.day.from_now)

    get_bandeja(item_type: 'task')

    expect(response).to have_http_status(:ok)
    rows = response.parsed_body['case_tasks']
    expect(rows.size).to eq(1)
    expect(rows.first['item_type']).to eq('task')
  end

  it 'item_type=meeting devuelve solo reuniones, con organizer como responsable' do
    crear_tarea(due_at: 1.day.from_now)
    crear_reunion(starts_at: 1.day.from_now, organizer: other_agent)

    get_bandeja(item_type: 'meeting', assignee_id: other_agent.id)

    expect(response).to have_http_status(:ok)
    rows = response.parsed_body['case_tasks']
    expect(rows.size).to eq(1)
    expect(rows.first['item_type']).to eq('meeting')
    expect(rows.first['organizer']['id']).to eq(other_agent.id)
  end

  it 'sin item_type fusiona tareas y reuniones ordenadas por fecha (due_at/starts_at)' do
    crear_tarea(due_at: 3.days.from_now)
    crear_reunion(starts_at: 1.day.from_now)
    crear_tarea(due_at: 2.days.from_now)

    get_bandeja

    rows = response.parsed_body['case_tasks']
    expect(rows.pluck('item_type')).to eq(%w[meeting task task])
    expect(response.parsed_body['meta']['count']).to eq(3)
  end

  it 'la paginación de la vista fusionada es correcta cruzando la frontera entre páginas' do
    # 30 tareas + 5 reuniones, todas ordenadas por fecha ascendente. Página 1 = 25
    # primeras, página 2 = las 10 restantes.
    35.times { |i| i.even? ? crear_tarea(due_at: (i + 1).hours.from_now) : crear_reunion(starts_at: (i + 1).hours.from_now) }

    get_bandeja(page: 1)
    page1 = response.parsed_body['case_tasks']
    get_bandeja(page: 2)
    page2 = response.parsed_body['case_tasks']

    expect(page1.size).to eq(25)
    expect(page2.size).to eq(10)
    expect(response.parsed_body['meta']['count']).to eq(35)
    # sin solapamiento
    expect((page1.map { |r| [r['item_type'], r['id']] } & page2.map { |r| [r['item_type'], r['id']] })).to be_empty
  end

  it 'status=pending incluye reuniones scheduled; status=done excluye reuniones scheduled' do
    crear_reunion(starts_at: 1.day.from_now, status: 'scheduled')
    crear_reunion(starts_at: 2.days.from_now, status: 'held')

    get_bandeja(item_type: 'meeting', status: 'pending')
    expect(response.parsed_body['case_tasks'].size).to eq(1)
    expect(response.parsed_body['case_tasks'].first['status']).to eq('scheduled')

    get_bandeja(item_type: 'meeting', status: 'done')
    expect(response.parsed_body['case_tasks'].size).to eq(1)
    expect(response.parsed_body['case_tasks'].first['status']).to eq('held')
  end

  it 'requester_id filtra a cero reuniones (CaseMeeting no tiene solicitante)' do
    crear_reunion(starts_at: 1.day.from_now)

    get_bandeja(item_type: 'meeting', requester_id: agent.id)

    expect(response.parsed_body['case_tasks']).to be_empty
  end
end
