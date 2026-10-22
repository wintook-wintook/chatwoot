# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T4: qué mueve cada etapa.
RSpec.describe Cases::StageMovers do
  let(:account) { create(:account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:otro)    { CaseType.create!(account: account, name: 'Otro', color: '#64748b') }
  let(:columns) do
    CaseTypeColumn.seed_defaults_for(soporte, itil: false)
    soporte.case_type_columns.ordered.to_a
  end
  let(:nuevo)    { columns.find { |c| c.label == 'Nuevo' } }
  let(:proceso)  { columns.find { |c| c.label == 'En proceso' } }
  let(:cerrado)  { columns.find { |c| c.label == 'Cerrado' } }

  def rule(name, actions, conditions = [])
    CaseRule.create!(account: account, name: name, actions: actions, conditions: conditions)
  end

  it 'cuenta las obligatorias de la plantilla de cada etapa' do
    nuevo.task_templates.create!(account: account, title: 'A')
    nuevo.task_templates.create!(account: account, title: 'B', required: false)

    expect(described_class.new(soporte).call[nuevo.id][:required_count]).to eq(1)
  end

  it 'marca en qué etapa caen las reglas que cambian el estado, escalan o cierran' do
    rule('Escalar urgentes', [{ 'type' => 'escalate' }])
    rule('Cerrar spam', [{ 'type' => 'close_ticket' }])
    movers = described_class.new(soporte).call

    expect(movers[proceso.id][:rules_in].pluck(:name)).to eq(['Escalar urgentes'])
    expect(movers[cerrado.id][:rules_in].pluck(:name)).to eq(['Cerrar spam'])
  end

  it 'ignora las reglas cuyo tipo excluye a este' do
    rule('Solo del otro tipo', [{ 'type' => 'close_ticket' }],
         [{ 'field' => 'case_type', 'operator' => 'eq', 'value' => otro.id }])

    expect(described_class.new(soporte).call[cerrado.id][:rules_in]).to be_empty
  end

  it 'avisa cuando una etapa avanza sola y una regla también le cambia el estado' do
    nuevo.update!(advance_mode: :automatic)
    rule('Escalar urgentes', [{ 'type' => 'escalate' }])
    movers = described_class.new(soporte).call

    expect(movers[nuevo.id][:warnings].pluck(:name)).to eq(['Escalar urgentes'])
    expect(movers[proceso.id][:warnings]).to be_empty
  end
end
