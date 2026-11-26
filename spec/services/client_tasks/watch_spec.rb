# frozen_string_literal: true

require 'rails_helper'

# Tareas con el cliente — «Esperando al cliente» en Mi día del responsable del caso, «Recordarle» y el filtro
# «Quién la hace» en Tareas.
RSpec.describe ClientTasks::Watch do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator, name: 'Luis') }
  let(:other) { create(:user, account: account, name: 'Rosa') }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez', organization_id: organization.id) }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, title: 'Implementación', contact: contact, organization: organization, case_type: type,
                       conversation: conversation, assignee: user)
  end
  let(:others_ticket) { CaseTicket.create!(account: account, title: 'Otro', contact: contact, case_type: type, assignee: other) }

  def client_task(title, due_at, case_ticket: ticket)
    case_ticket.case_tasks.create!(account: account, title: title, audience: :client, due_at: due_at)
  end

  before do
    client_task('Enviar constancia', 3.days.ago)
    client_task('Probar facturación', 2.days.from_now)
    client_task('Aprobar diseño', nil)
    client_task('Mandar logo', 1.day.ago).tap { |t| t.update!(status: :done) }
    client_task('De otro', 1.day.ago, case_ticket: others_ticket)
    ticket.case_tasks.create!(account: account, title: 'Nuestra', due_at: 1.day.ago, assignee: user)
  end

  it 'junta las del cliente de MIS casos: vencidas, por vencer, en espera y las que acaba de terminar' do
    result = described_class.new(account, user).call
    expect(result[:counts]).to eq(overdue: 1, soon: 1, waiting: 1, done: 1)
    expect(result[:overdue].first).to include(title: 'Enviar constancia', days_overdue: 3, client: 'Acme')
    expect(result[:done].first[:title]).to eq('Mandar logo')
    expect(described_class.new(account, other).call[:counts][:overdue]).to eq(1)
  end

  it 'el endpoint da la lista y «Recordarle» le escribe por su conversación', type: :request do
    get "/api/v1/accounts/#{account.id}/case_tasks/client_watch", headers: user.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('counts', 'overdue')).to eq(1)

    task = account.case_tasks.find_by(title: 'Enviar constancia')
    post "/api/v1/accounts/#{account.id}/case_tasks/#{task.id}/remind_client", headers: user.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('sent' => true)
    expect(conversation.messages.outgoing.last.content).to include('Enviar constancia')
  end

  it 'Tareas: «Del cliente» trae las del cliente de mis casos; «Nuestras», las demás' do
    query = lambda do |extra|
      Cases::TasksInboxQuery.new(account: account, current_user: user, params: { item_type: 'task' }.merge(extra)).call
    end
    mine = query.call(audience: 'client')[:rows].map { |task, _| task.title }
    expect(mine).to contain_exactly('Enviar constancia', 'Probar facturación', 'Aprobar diseño') # pendientes, como siempre
    expect(query.call(audience: 'client', status: 'all')[:rows].size).to eq(4)
    expect(query.call(audience: 'client', assignee_id: 'all')[:rows].size).to eq(4)
    expect(query.call(audience: 'ours')[:rows].map { |task, _| task.title }).to eq(['Nuestra'])
  end
end
