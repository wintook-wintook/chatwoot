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

  it 'un día = lo de la página Mi día: sin citas ya realizadas ni lo pasado a otro día, con las sin fecha' do
    now = Time.current
    ticket.case_meetings.create!(account: account, title: 'Visita', organizer: user, starts_at: now.end_of_day - 1.hour,
                                 ends_at: now.end_of_day - 30.minutes, status: :scheduled)
    ticket.case_meetings.create!(account: account, title: 'Ya fue', organizer: user, starts_at: now.beginning_of_day + 1.hour,
                                 ends_at: now.beginning_of_day + 2.hours, status: :held)
    ticket.case_tasks.create!(account: account, title: 'Vence hoy', assignee: user, due_at: now.end_of_day)
    ticket.case_tasks.create!(account: account, title: 'Sin fecha', assignee: user)
    ticket.case_tasks.create!(account: account, title: 'Para mañana', assignee: user, due_at: now.end_of_day,
                              planned_on: Time.zone.tomorrow)
    today = Time.zone.today.iso8601

    result = call('my_agenda', { 'from' => today, 'to' => today })

    expect(result[:meetings].pluck(:title)).to eq(['Visita'])
    expect(result[:tasks].pluck(:title)).to contain_exactly('Vence hoy', 'Sin fecha')
    expect(result).to include(more_tasks: 0, later_count: 1)
  end

  it 'un día muestra las primeras y dice cuántas más hay' do
    12.times { |i| ticket.case_tasks.create!(account: account, title: "T#{i}", assignee: user, due_at: Time.current.end_of_day) }
    today = Time.zone.today.iso8601

    result = call('my_agenda', { 'from' => today, 'to' => today })

    expect(result[:tasks].size).to eq(Assistant::AgendaTools::DAY_LIMIT)
    expect(result[:more_tasks]).to eq(2)
  end

  it 'varios días: solo citas agendadas y respeta lo pasado a un día del rango' do
    now = Time.current
    ticket.case_meetings.create!(account: account, title: 'Ya fue', organizer: user, starts_at: now.beginning_of_day + 1.hour,
                                 ends_at: now.beginning_of_day + 2.hours, status: :held)
    ticket.case_tasks.create!(account: account, title: 'En el rango', assignee: user, due_at: now + 30.days,
                              planned_on: Time.zone.today + 2)
    ticket.case_tasks.create!(account: account, title: 'Fuera', assignee: user, due_at: now.end_of_day,
                              planned_on: Time.zone.today + 20)
    ticket.case_tasks.create!(account: account, title: 'Vence hoy', assignee: user, due_at: now.end_of_day)

    result = call('my_agenda', { 'from' => Time.zone.today.iso8601, 'to' => (Time.zone.today + 6).iso8601 })

    expect(result[:meetings]).to be_empty
    expect(result[:tasks].pluck(:title)).to contain_exactly('En el rango', 'Vence hoy')
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
