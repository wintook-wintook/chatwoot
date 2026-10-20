# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F5: métricas del embudo comercial.
RSpec.describe V2::Reports::Cases::PipelineBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:seller)  { create(:user, account: account, name: 'Vendedora') }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let!(:lost_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :lost, label: 'Precio') }
  let(:won_reason)       { account.case_outcome_reasons.outcome_won.ordered.first }
  let(:postponed_reason) { account.case_outcome_reasons.outcome_postponed.ordered.first }
  let(:report) { described_class.new(account: account, params: {}).build }

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Opp', contact: contact, case_type: venta, assignee: seller,
                         status: :in_progress }.merge(attrs))
  end

  def column(label)
    venta.case_type_columns.find_by!(label: label)
  end

  before do
    opportunity(amount: 1000, currency: 'MXN', case_type_column_id: column('Propuesta').id,
                expected_close_at: Date.new(2026, 11, 15))
    opportunity(amount: 500, currency: 'USD', case_type_column_id: column('Negociación').id)
    opportunity(amount: 2000, currency: 'MXN').close_with_outcome!(:won, reason_id: won_reason.id)
    opportunity(amount: 300, currency: 'MXN').close_with_outcome!(:lost, reason_id: lost_reason.id)
    # Soporte no entra al embudo.
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
  end

  it 'separa lo abierto por moneda con su ponderado' do
    expect(report[:summary][:open_count]).to eq(2)
    expect(report[:summary][:open_value]).to contain_exactly(
      { currency: 'MXN', amount: 1000.0, weighted: 500.0 },
      { currency: 'USD', amount: 500.0, weighted: 375.0 }
    )
  end

  it 'cuenta lo decidido y la tasa de cierre (ganadas / ganadas + perdidas)' do
    expect(report[:summary]).to include(won_count: 1, lost_count: 1, cancelled_count: 0, win_rate: 50)
    expect(report[:summary][:won_value]).to eq([{ currency: 'MXN', amount: 2000.0, count: 1 }])
  end

  it 'agrupa las abiertas por etapa del embudo, en orden' do
    expect(report[:stages].pluck(:label)).to eq(%w[Propuesta Negociación])
  end

  it 'motivos, vendedor y pronóstico' do
    expect(report[:loss_reasons]).to eq([{ outcome: 'lost', label: 'Precio', count: 1 }])
    expect(report[:by_assignee].first).to include(assignee_name: 'Vendedora', open_count: 2, won_count: 1, win_rate: 50)
    expect(report[:forecast]).to eq([{ currency: 'MXN', amount: 1000.0, weighted: 500.0, count: 1, month: '2026-11' }])
  end

  it 'cuenta como recuperada una ganada que antes se había perdido' do
    opp = opportunity(amount: 100, currency: 'MXN')
    opp.close_with_outcome!(:lost, reason_id: lost_reason.id)
    opp.reopen!(reason: 'Volvió')
    opp.close_with_outcome!(:won, reason_id: won_reason.id)

    expect(report[:summary][:recovered_count]).to eq(1)
  end

  it 'el resto de los reportes de casos ya lee el resultado real' do
    buckets = V2::Reports::Cases::DistributionBuilder.new(account: account, params: { case_type_id: venta.id }).outcome
    expect(buckets).to include(open: 2, won: 1, lost: 1)
  end

  it 'scopes de clase: una oportunidad no cae en non_commercial y un caso sin tipo sí' do
    sin_tipo = CaseTicket.create!(account: account, title: 'Sin tipo', contact: contact)
    expect(account.case_tickets.non_commercial).to include(sin_tipo)
    expect(account.case_tickets.non_commercial.where(case_type: venta)).to be_empty
    expect(account.case_tickets.of_class('support')).to include(sin_tipo)
    expect(account.case_tickets.commercial.count).to eq(4)
  end
end
