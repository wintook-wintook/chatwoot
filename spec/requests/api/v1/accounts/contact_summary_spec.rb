# frozen_string_literal: true

require 'rails_helper'

# Página del contacto: Resumen (cifras + actividad), Tareas de sus casos y sus
# conversaciones, respetando el rol.
RSpec.describe 'Contact page API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:base)    { "/api/v1/accounts/#{account.id}" }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent)
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: other)
    mine = CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta,
                              assignee: agent, amount: 1200, currency: 'MXN')
    CaseTicket.create!(account: account, title: 'Otra', contact: contact, case_type: venta, assignee: other,
                       amount: 500, currency: 'MXN')
    CaseTask.create!(account: account, case_ticket: mine, title: 'Llamar', due_at: 1.day.from_now)
    contact.notes.create!(account: account, user: admin, content: '<p>Pidió <b>cotización</b></p>')
  end

  def as_seller(user)
    seller = AccessRole.for_account(account).find { |role| role.key == 'seller' }
    account.account_users.find_by(user: user).update!(access_role: seller)
  end

  it 'el Resumen trae cifras, próxima tarea y actividad mezclada' do
    get "#{base}/contacts/#{contact.id}/summary", headers: admin.create_new_auth_token, as: :json
    stats = response.parsed_body['stats']
    expect(stats['open_conversations']).to eq(2)
    expect(stats['open_cases']).to eq(2)
    expect(stats['opportunities_amounts']).to eq([{ 'currency' => 'MXN', 'amount' => 1700.0 }])
    expect(stats['next_task']['title']).to eq('Llamar')
    kinds = response.parsed_body['activity'].pluck('kind')
    expect(kinds).to include('conversation', 'case', 'note')
    expect(response.parsed_body['activity'].find { |i| i['kind'] == 'note' }['text']).to eq('Pidió cotización')
  end

  it 'con «solo lo suyo» solo cuenta lo suyo' do
    as_seller(agent)
    get "#{base}/contacts/#{contact.id}/summary", headers: agent.create_new_auth_token, as: :json
    stats = response.parsed_body['stats']
    expect(stats['open_conversations']).to eq(1)
    expect(stats['open_cases']).to eq(1)
    expect(stats['opportunities_amounts']).to eq([{ 'currency' => 'MXN', 'amount' => 1200.0 }])
  end

  it 'sin «ver montos» no manda importes' do
    technician = AccessRole.for_account(account).find { |role| role.key == 'technician' }
    account.account_users.find_by(user: agent).update!(access_role: technician)
    get "#{base}/contacts/#{contact.id}/summary", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['stats']['opportunities_amounts']).to be_nil
  end

  it 'Tareas filtra por contacto' do
    CaseTask.create!(account: account, case_ticket: CaseTicket.create!(account: account, title: 'Ajeno',
                                                                       contact: create(:contact, account: account)),
                     title: 'De otro contacto', due_at: 1.day.from_now)
    get "#{base}/case_tasks", params: { contact_id: contact.id, assignee_id: 'all', item_type: 'task' },
                              headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tasks'].pluck('title')).to eq(['Llamar'])
  end

  it 'las conversaciones del contacto respetan «solo lo suyo»' do
    as_seller(agent)
    get "#{base}/contacts/#{contact.id}/conversations", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['payload'].size).to eq(1)
  end
end
