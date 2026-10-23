# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F2: servicios/categorías por tipo de caso.
RSpec.describe CaseTicket, 'clasificación por tipo de caso' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6') }
  let!(:global_cat)  { CaseCategory.create!(account: account, name: 'General') }
  let!(:venta_cat)   { CaseCategory.create!(account: account, name: 'Licencias', case_type: venta) }
  let!(:venta_svc)   { CaseService.create!(account: account, name: 'CRM', color: '#64748b', case_type: venta) }

  def ticket(attrs = {})
    CaseTicket.create!({ account: account, title: 'Caso', contact: contact, case_type: soporte }.merge(attrs))
  end

  it 'for_type devuelve globales + propios del tipo' do
    expect(account.case_categories.for_type(venta.id)).to contain_exactly(global_cat, venta_cat)
    expect(account.case_categories.for_type(soporte.id)).to contain_exactly(global_cat)
  end

  it 'la subcategoría hereda el tipo del padre, y lo sigue si el padre cambia' do
    sub = CaseCategory.create!(account: account, name: 'Anual', parent: venta_cat, case_type: soporte)
    expect(sub.case_type_id).to eq(venta.id)

    venta_cat.update!(case_type: nil)
    expect(sub.reload.case_type_id).to be_nil
  end

  it 'rechaza un tipo de otra cuenta' do
    ajeno = CaseType.create!(account: create(:account), name: 'X', color: '#000000')
    expect(CaseCategory.new(account: account, name: 'Y', case_type: ajeno)).not_to be_valid
  end

  it 'al crear un caso, la clasificación de otro tipo se limpia sola' do
    t = ticket(category: venta_cat, affected_service: venta_svc)
    expect(t.category_id).to be_nil
    expect(t.affected_service_id).to be_nil
  end

  it 'al cambiar de tipo se limpia lo que ya no aplica y se conserva lo global' do
    t = ticket(case_type: venta, category: venta_cat)
    expect(t.category_id).to eq(venta_cat.id)

    t.update!(case_type: soporte)
    expect(t.category_id).to be_nil

    t.update!(category: global_cat)
    t.update!(case_type: venta)
    expect(t.category_id).to eq(global_cat.id)
  end

  it 'sin cambiar de tipo, asignar una categoría ajena es inválido' do
    t = ticket
    t.category = venta_cat
    expect(t).not_to be_valid
    expect(t.errors[:category_id]).to be_present
  end

  it 'borrar el tipo borra su clasificación propia y deja la global' do
    t = ticket(case_type: venta, category: venta_cat)
    venta.destroy!

    expect(CaseCategory.exists?(venta_cat.id)).to be(false)
    expect(CaseService.exists?(venta_svc.id)).to be(false)
    expect(CaseCategory.exists?(global_cat.id)).to be(true)
    expect(t.reload.category_id).to be_nil
  end

  it 'el intake descarta clasificación que no es del tipo elegido' do
    intake = Cases::Ai::Intake.allocate
    types = [[soporte.id, 'Soporte'], [venta.id, 'Venta']]
    cats  = [[global_cat.id, 'General', nil], [venta_cat.id, 'Licencias', venta.id]]
    out = intake.send(:sanitize, { 'case_type_id' => soporte.id, 'category_id' => venta_cat.id }, types, [], cats)
    expect(out['category_id']).to be_nil

    out = intake.send(:sanitize, { 'case_type_id' => venta.id, 'category_id' => venta_cat.id }, types, [], cats)
    expect(out['category_id']).to eq(venta_cat.id)
  end
end
