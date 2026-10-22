# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T3: avance al terminar las obligatorias.
RSpec.describe Cases::StageAdvance do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:columns) do
    CaseTypeColumn.seed_defaults_for(venta, itil: false)
    venta.case_type_columns.ordered.to_a
  end
  let(:prospecto)   { columns[0] }
  let(:calificado)  { columns[1] }
  let(:negociacion) { columns.find { |c| c.label == 'Negociación' } }
  let(:ganada)      { columns.find { |c| c.outcome == 'won' } }

  def template(column, attrs = {})
    column.task_templates.create!({ account: account, title: 'Tarea', position: column.task_templates.count }.merge(attrs))
  end

  def new_case(attrs = {})
    CaseTicket.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta,
                         assignee: agent }.merge(attrs))
  end

  def finish(ticket, column)
    ticket.case_tasks.where(case_type_column_id: column.id).find_each { |t| t.update!(status: :done) }
    ticket.reload
  end

  it 'en «Sugerir» no mueve el caso: queda listo con la siguiente etapa' do
    template(prospecto, title: 'Calificar')
    ticket = finish(new_case, prospecto)

    expect(ticket.current_stage_column).to eq(prospecto)
    expect(described_class.new(ticket).summary).to include(ready: true, mode: 'suggest', needs_doc: false,
                                                           next: { id: calificado.id, label: 'Calificado' },
                                                           required_total: 1, required_done: 1)
  end

  it 'en «Automático» pasa sola, lo anota y nacen las tareas de la siguiente etapa' do
    prospecto.update!(advance_mode: :automatic)
    template(prospecto, title: 'Calificar')
    template(calificado, title: 'Enviar brochure')
    ticket = finish(new_case, prospecto)

    expect(ticket.case_type_column_id).to eq(calificado.id)
    expect(ticket.case_events.stage_advanced.last.payload).to include('from' => 'Prospecto', 'to' => 'Calificado')
    expect(ticket.case_tasks.pending.pluck(:title)).to eq(['Enviar brochure'])
  end

  it 'las tareas no obligatorias no cuentan, y sin obligatorias no hay avance' do
    prospecto.update!(advance_mode: :automatic)
    template(prospecto, title: 'Opcional', required: false)
    ticket = finish(new_case, prospecto)

    expect(ticket.case_type_column_id).not_to eq(calificado.id)
    expect(described_class.new(ticket).summary).to be_nil
  end

  it 'en «Manual» no hace nada' do
    prospecto.update!(advance_mode: :manual)
    template(prospecto)
    ticket = finish(new_case, prospecto)

    expect(ticket.current_stage_column).to eq(prospecto)
    expect(ticket.case_tasks.count).to eq(1)
  end

  context 'cuando la siguiente etapa pide documentar' do
    let(:ticket) do
      negociacion.update!(advance_mode: :automatic)
      template(negociacion, title: 'Negociar precio')
      t = new_case
      t.update!(status: :in_progress, case_type_column_id: negociacion.id)
      t
    end

    it 'salta la espera (Pospuesta), no avanza y crea una sola tarea obligatoria «Documenta…»' do
      finish(ticket, negociacion)
      described_class.new(ticket.reload).call

      doc = ticket.case_tasks.where.not(documentation_for_column_id: nil)
      expect(doc.count).to eq(1)
      expect(doc.first).to have_attributes(title: 'Documenta para pasar a «Ganada»', required: true,
                                           documentation_for_column_id: ganada.id, status: 'pending')
      expect(ticket.reload.case_type_column_id).to eq(negociacion.id)
    end

    it 'la tarea «Documenta…» se completa sola al documentar el paso' do
      finish(ticket, negociacion)
      ticket.close_with_outcome!('won', actor: agent)
      ticket.update!(case_type_column_id: ganada.id)

      expect(ticket.case_tasks.find_by(documentation_for_column_id: ganada.id).status).to eq('done')
    end
  end
end
