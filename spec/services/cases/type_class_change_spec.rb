# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — «Cambiar de clase» un tipo: los casos de antes se quedan tal cual,
# los nuevos nacen en la clase nueva.
RSpec.describe Cases::TypeClassChange do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:type)    { CaseType.create!(account: account, name: 'Implementación', color: '#06b6d4', prefix: 'IMP') }

  def new_case(case_type = type)
    CaseTicket.create!(account: account, title: 'Caso', contact: contact, case_type: case_type)
  end

  it 'sin casos cambia la clase directo y le pone las etapas de la clase nueva' do
    result = described_class.new(type, 'project').call

    expect(result.type).to eq(type)
    expect(type.reload.case_class).to eq('project')
    expect(type.case_type_columns.ordered.first.label).to eq('Planeación')
    expect(result.retired).to be_nil
  end

  context 'con casos' do
    let!(:old_case) { new_case }

    before do
      type.case_type_fields.create!(account: account, key: 'serie', label: 'Número de serie', required: true)
    end

    it 'crea el tipo en la otra clase y retira el de antes con sus casos tal cual' do
      old_column = old_case.reload.current_stage_column
      result = described_class.new(type, 'project').call

      expect(result.type).to have_attributes(name: 'Implementación', case_class: 'project', prefix: 'IMP')
      expect(result.type.case_type_fields.pluck(:key)).to eq(['serie'])
      expect(result.retired).to have_attributes(name: 'Implementación (anterior)', case_class: 'support')
      expect(result.retired).to be_retired
      expect(result.kept_cases).to eq(1)
      expect(old_case.reload.case_type).to eq(type)
      expect(old_case.case_type.case_class).to eq('support')
      expect(old_case.current_stage_column).to eq(old_column)
    end

    it 'el folio sigue la serie con el mismo prefijo, sin repetir' do
      result = described_class.new(type, 'project').call
      later = CaseTicket.create!(account: account, title: 'Nuevo', contact: contact, case_type: result.type,
                                 project_start_on: Date.current)

      expect(later.folio).not_to eq(old_case.folio)
      expect(later.folio).to start_with('IMP')
    end

    it 'no deja crear casos nuevos en el tipo retirado' do
      described_class.new(type, 'project').call

      expect { new_case(type.reload) }.to raise_error(ActiveRecord::RecordInvalid, /retirado/)
    end

    it 'pasa las automatizaciones «Asignar Caso» al tipo nuevo y suma el nuevo a las reglas' do
      auto = AutomationRule.create!(account: account, name: 'Asignar', event_name: 'conversation_created',
                                    conditions: [{ 'attribute_key' => 'status', 'filter_operator' => 'equal_to',
                                                   'values' => ['open'], 'query_operator' => nil }],
                                    actions: [{ 'action_name' => 'assign_case_type', 'action_params' => [type.id] }])
      rule = CaseRule.create!(account: account, name: 'Urgentes', actions: [{ 'type' => 'escalate' }],
                              conditions: [{ 'field' => 'case_type', 'operator' => 'eq', 'value' => type.id }])
      result = described_class.new(type, 'project').call

      expect(auto.reload.actions.first['action_params']).to eq([result.type.id])
      expect(rule.reload.conditions.first).to include('operator' => 'in', 'value' => [type.id.to_s, result.type.id.to_s])
      expect(result.automations.pluck(:name)).to eq(['Asignar'])
    end

    it '@crear_ticket por nombre encuentra el tipo nuevo, no el retirado' do
      result = described_class.new(type, 'project').call

      expect(account.case_types.active.where('LOWER(name) = ?', 'implementación').pick(:id)).to eq(result.type.id)
    end
  end
end
