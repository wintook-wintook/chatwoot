# frozen_string_literal: true

require 'rails_helper'

# Dali — personas del equipo (team_members) y la agenda de otra persona (my_agenda con user_id).
RSpec.describe Assistant::AgendaTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator, name: 'John Admin') }
  let(:ana) { create(:user, account: account, role: :agent, name: 'Ana Ruiz') }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: create(:contact, account: account, name: 'Ana López')) }

  def call(name, args) = tools.call(name, args)[:result]

  it 'team_members busca en el equipo (no en contactos)' do
    ana
    found = call('team_members', { 'query' => 'ana' })[:team_members]
    expect(found.pluck(:name)).to eq(['Ana Ruiz'])
    expect(found.first).to include(id: ana.id, email: ana.email)
  end

  it 'team_members sin texto trae a todo el equipo y marca al usuario' do
    ana
    found = call('team_members', {})[:team_members]
    expect(found.pluck(:name)).to contain_exactly('Ana Ruiz', 'John Admin')
    expect(found.find { |u| u[:id] == user.id }[:you]).to be(true)
  end

  it 'my_agenda con user_id trae el día de esa persona' do
    ticket.case_tasks.create!(account: account, title: 'De Ana', assignee: ana, due_at: Time.current.end_of_day)
    ticket.case_tasks.create!(account: account, title: 'Mía', assignee: user, due_at: Time.current.end_of_day)
    today = Time.zone.today.iso8601

    result = call('my_agenda', { 'from' => today, 'to' => today, 'user_id' => ana.id })

    expect(result[:person]).to eq('Ana Ruiz')
    expect(result[:tasks].pluck(:title)).to eq(['De Ana'])
    expect(call('my_agenda', { 'from' => today, 'to' => today })[:tasks].pluck(:title)).to eq(['Mía'])
  end

  it 'con Agenda en «solo lo suyo» no ve el día de otro' do
    own = instance_double(Access::Grant, own?: true)
    allow(own).to receive(:own?).with(:agenda).and_return(true)
    limited = Assistant::Tools.new(account: account, user: user, grant: own, zone: Time.zone)
    today = Time.zone.today.iso8601

    result = limited.call('my_agenda', { 'from' => today, 'to' => today, 'user_id' => ana.id })[:result]

    expect(result[:error]).to include('Solo puedes ver tu propia agenda')
  end

  it 'propose_task asigna a la persona del equipo' do
    proposal = tools.call('propose_task', { 'title' => 'Llamar al proveedor', 'assignee_id' => ana.id })[:proposal]
    expect(proposal['payload']['assignee_id']).to eq(ana.id)
  end

  it 'el prompt trae la regla de equipo o cliente' do
    expect(Assistant::Chat::STATIC_PROMPT).to include('team_members, nunca search', 'Si no está en el equipo, búscala con search')
  end
end
