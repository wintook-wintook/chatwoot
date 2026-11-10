# frozen_string_literal: true

require 'rails_helper'

# Dali — tareas con el cliente: qué le falta, quién tiene vencidas y asignarle una.
RSpec.describe Assistant::ClientTaskTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Implementación', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, title: 'Implementar', contact: contact, organization: organization, case_type: type,
                       conversation: conversation)
  end

  before { Current.user = user }
  after { Current.user = nil }

  it 'lista lo que le falta a la organización y las vencidas' do
    ticket.case_tasks.create!(account: account, title: 'Probar', audience: :client, due_at: 1.day.ago)
    ticket.case_tasks.create!(account: account, title: 'Configurar', audience: :visible)
    ticket.case_tasks.create!(account: account, title: 'Interna')

    all = tools.call('client_tasks', { 'organization_id' => organization.id })[:result][:tasks]
    expect(all.pluck(:title)).to contain_exactly('Probar', 'Configurar')
    overdue = tools.call('client_tasks', { 'overdue' => true })[:result][:tasks]
    expect(overdue.pluck(:title)).to eq(['Probar'])
  end

  it 'propone la tarea del cliente y al confirmar la crea y le avisa con el enlace' do
    proposal = tools.call('propose_client_task', { 'case_id' => ticket.id, 'title' => 'Probar la facturación',
                                                   'requires_file' => true })[:proposal]
    expect(proposal['labels']['rows']).to include(%w[CLIENT Acme])

    result = executor.call('client_task', proposal['payload'])
    task = ticket.case_tasks.last
    expect(task).to have_attributes(audience: 'client', requires_file: true, title: 'Probar la facturación')
    expect(result['label']).to include('se le avisó')
    expect(conversation.messages.outgoing.last.content).to include('/cliente/')
  end
end
