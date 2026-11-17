# frozen_string_literal: true

require 'rails_helper'

# «Guardar columnas» (Tipos de caso › Columnas) manda el set completo. Las etapas de
# resultado (Ganada/Perdida/Cancelada) y su probabilidad no se editan ahí: si el payload
# no las trae, deben quedarse como estaban.
RSpec.describe Cases::TypeColumnsReplaceService do
  let(:account) { create(:account) }
  let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }

  def payload(with_commercial:)
    venta.case_type_columns.ordered.map do |c|
      row = { id: c.id, label: c.label, color: c.color, position: c.position, statuses: c.statuses }
      with_commercial ? row.merge(outcome: c.outcome, probability: c.probability) : row
    end
  end

  def snapshot = venta.case_type_columns.ordered.pluck(:label, :outcome, :probability)

  it 'sin outcome ni probability en el payload, se conservan' do
    before = snapshot
    expect(before.map(&:second)).to include('won', 'lost')

    result = described_class.new(case_type: venta, columns_params: payload(with_commercial: false)).call

    expect(result.success?).to be(true)
    expect(snapshot).to eq(before)
  end

  it 'con outcome vacío explícito, la etapa deja de ser de resultado' do
    rows = payload(with_commercial: true)
    won = rows.find { |r| r[:outcome] == 'won' }
    won[:outcome] = nil

    described_class.new(case_type: venta, columns_params: rows).call

    expect(venta.case_type_columns.find(won[:id]).outcome).to be_nil
  end

  it 'cambia la probabilidad cuando viene' do
    rows = payload(with_commercial: true)
    rows.first[:probability] = 15

    described_class.new(case_type: venta, columns_params: rows).call

    expect(venta.case_type_columns.find(rows.first[:id]).probability).to eq(15)
  end
end
