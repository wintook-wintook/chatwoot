# frozen_string_literal: true

require 'rails_helper'

# Plan-Metricas-Comercial M2 — oportunidades estancadas (a pedido).
RSpec.describe V2::Reports::Cases::PipelineStaleBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:won_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :won) }
  let(:lost_reason) { account.case_outcome_reasons.outcome_lost.first }

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Opp', contact: contact, case_type: venta,
                         status: :in_progress }.merge(attrs))
  end

  def column(label)
    venta.case_type_columns.find_by!(label: label)
  end

  it 'cuenta los días desde el último cambio de etapa (columna o estado), no desde el alta' do
    vieja = nil
    movida = nil
    travel_to 40.days.ago do
      vieja = opportunity(amount: 100, currency: 'MXN', case_type_column_id: column('Propuesta').id)
      movida = opportunity(amount: 200, currency: 'MXN', case_type_column_id: column('Propuesta').id)
    end
    travel_to 3.days.ago do
      CaseEvent.create!(case_ticket: movida, account: account, event_type: :column_changed, origin: :agent)
    end

    report = described_class.new(account: account, params: {}).build

    expect(report[:threshold_days]).to eq(15)
    expect(report[:items].pluck(:id)).to eq([vieja.id])
    expect(report[:items].first).to include(stage: 'Propuesta', amount: 100.0)
    expect(report[:items].first[:days_in_stage]).to be >= 39
    expect(report[:by_stage]).to eq('Propuesta' => 1)
  end

  it 'respeta el umbral pedido' do
    travel_to(5.days.ago) { opportunity(case_type_column_id: column('Propuesta').id) }
    expect(described_class.new(account: account, params: { threshold_days: '3' }).build[:items].size).to eq(1)
    expect(described_class.new(account: account, params: {}).build[:items]).to be_empty
  end
end
