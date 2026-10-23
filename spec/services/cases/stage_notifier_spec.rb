# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa: avisos de tareas nuevas y etapa lista.
RSpec.describe Cases::StageNotifier do
  let(:account) { create(:account, locale: 'es') }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:columns) do
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    venta.case_type_columns.ordered.to_a
  end
  let(:prospecto) { columns[0] }

  def template(attrs = {})
    prospecto.task_templates.create!({ account: account, title: 'Tarea', position: prospecto.task_templates.count }.merge(attrs))
  end

  def new_case
    CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta, assignee: agent)
  end

  it 'al nacer las tareas de la etapa manda UN aviso por persona con sus tareas' do
    template(title: 'Calificar')
    template(title: 'Llamar')
    template(title: 'Revisar', assignee_mode: :user, assignee_id: other.id)
    ticket = new_case

    mine = agent.notifications.case_stage_tasks.sole
    expect(mine.primary_actor).to eq(ticket)
    expect(mine.meta).to include('count' => 2, 'stage' => 'Prospecto')
    expect(mine.push_message_body).to include('2 tareas nuevas', 'Calificar', 'Llamar')
    expect(other.notifications.case_stage_tasks.sole.meta['count']).to eq(1)
  end

  it 'una tarea de equipo sin persona avisa a todo el equipo' do
    team = create(:team, account: account)
    member = create(:user, account: account, role: :agent)
    create(:team_member, team: team, user: member)
    template(assignee_mode: :team, team_id: team.id)
    new_case

    expect(member.notifications.case_stage_tasks.count).to eq(1)
  end

  it 'no avisa a quien hizo el movimiento' do
    template
    Current.user = agent
    new_case

    expect(agent.notifications.case_stage_tasks).to be_empty
  ensure
    Current.reset
  end

  it 'al terminar las obligatorias (Sugerir) avisa al responsable que puede pasar' do
    template(title: 'Calificar', assignee_mode: :user, assignee_id: other.id)
    ticket = new_case
    Current.user = other
    ticket.case_tasks.sole.update!(status: :done)

    ready = agent.notifications.case_stage_ready.sole
    expect(ready.push_message_body).to eq('Se terminaron las tareas de Prospecto: ¿pasar a Calificado?')
  ensure
    Current.reset
  end

  it 'una tarea manual marcada obligatoria también cuenta para avanzar' do
    template(title: 'De la plantilla')
    ticket = new_case
    manual = ticket.case_tasks.create!(account: account, title: 'Visto bueno', required: true,
                                       case_type_column: prospecto)
    ticket.case_tasks.find_by(title: 'De la plantilla').update!(status: :done)
    expect(Cases::StageAdvance.new(ticket.reload).summary).to include(ready: false, required_total: 2)

    manual.update!(status: :done)
    expect(Cases::StageAdvance.new(ticket.reload).summary).to include(ready: true)
  end
end
