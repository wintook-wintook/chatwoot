# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T2: las tareas nacen al entrar a la etapa.
RSpec.describe Cases::StageTasksService do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:columns) do
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    venta.case_type_columns.ordered.to_a
  end
  let(:prospecto) { columns[0] }
  let(:calificado) { columns[1] }

  def template(column, attrs = {})
    column.task_templates.create!({ account: account, title: 'Tarea', position: column.task_templates.count }.merge(attrs))
  end

  def new_case(attrs = {})
    CaseTicket.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta,
                         assignee: agent }.merge(attrs))
  end

  it 'al crear el caso nacen las tareas de su primera etapa, del responsable y con vencimiento desde hoy' do
    template(prospecto, title: 'Calificar presupuesto', due_after_hours: 48, priority: :high)
    ticket = new_case

    task = ticket.case_tasks.sole
    expect(task).to have_attributes(title: 'Calificar presupuesto', assignee_id: agent.id, required: true,
                                    priority: 'high', case_type_column_id: prospecto.id)
    expect(task.due_at).to be_within(1.minute).of(48.hours.from_now)
    expect(ticket.case_events.stage_tasks_added.last.payload).to include('stage' => 'Prospecto', 'count' => 1)
  end

  it 'al pasar a otra etapa nacen las suyas, y al regresar no se duplican' do
    template(prospecto, title: 'Primera')
    template(calificado, title: 'Segunda')
    ticket = new_case
    ticket.update!(status: :in_progress, case_type_column_id: calificado.id)
    expect(ticket.case_tasks.pluck(:title)).to contain_exactly('Primera', 'Segunda')

    ticket.update!(case_type_column_id: prospecto.id, status: :assigned)
    ticket.update!(case_type_column_id: calificado.id, status: :in_progress)
    expect(ticket.case_tasks.count).to eq(2)
  end

  it 'una tarea de persona fija es de esa persona' do
    other = create(:user, account: account, role: :agent)
    template(prospecto, assignee_mode: :user, assignee_id: other.id)

    expect(new_case.case_tasks.sole.assignee_id).to eq(other.id)
  end

  it 'una tarea de equipo queda sin persona con el equipo anotado, salvo que el responsable sea del equipo' do
    team = create(:team, account: account)
    template(prospecto, assignee_mode: :team, team_id: team.id)
    expect(new_case.case_tasks.sole).to have_attributes(assignee_id: nil, team_id: team.id)

    create(:team_member, team: team, user: agent)
    expect(new_case.case_tasks.sole).to have_attributes(assignee_id: agent.id, team_id: team.id)
  end

  it 'un caso sin plantilla en su etapa no recibe tareas ni evento' do
    ticket = new_case

    expect(ticket.case_tasks).to be_empty
    expect(ticket.case_events.stage_tasks_added).to be_empty
  end

  it 'el camino de tareas muestra las etapas siguientes con plantilla y no las de caso cerrado' do
    template(calificado, title: 'Siguiente', required: false)
    ganada = columns.find { |c| c.outcome == 'won' }
    template(ganada, title: 'Facturar')
    plan = Cases::StagePlan.new(new_case).as_json

    expect(plan[:current]).to include(label: 'Prospecto')
    expect(plan[:upcoming]).to eq([{ id: calificado.id, label: 'Calificado',
                                     tasks: [{ title: 'Siguiente', required: false }] }])
  end
end
