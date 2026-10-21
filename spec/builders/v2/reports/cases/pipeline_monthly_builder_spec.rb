# frozen_string_literal: true

require 'rails_helper'

# Plan-Metricas-Comercial M3 — mes a mes (a pedido).
RSpec.describe V2::Reports::Cases::PipelineMonthlyBuilder do
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

  it 'da 12 meses con ganadas, perdidas, tasa y nuevas' do
    travel_to(Time.zone.parse('2026-08-10 12:00')) { opportunity }
    travel_to Time.zone.parse('2026-10-21 12:00') do
      opportunity(amount: 500, currency: 'MXN').close_with_outcome!(:won, reason_id: won_reason.id)
      opportunity(amount: 100, currency: 'MXN').close_with_outcome!(:lost, reason_id: lost_reason.id)

      months = described_class.new(account: account, params: {}).build[:months]

      expect(months.size).to eq(12)
      expect(months.first[:month]).to eq('2025-11')
      october = months.last
      expect(october).to include(month: '2026-10', won_count: 1, lost_count: 1, win_rate: 50, created_count: 2)
      expect(october[:won_value]).to eq([{ currency: 'MXN', amount: 500.0, count: 1 }])
      expect(months.find { |m| m[:month] == '2026-08' }).to include(created_count: 1, won_count: 0, win_rate: nil)
    end
  end

  it 'este año va de enero al mes actual y el año pasado de enero a diciembre' do
    travel_to Time.zone.parse('2026-10-21 12:00') do
      this_year = described_class.new(account: account, params: { span: 'this_year' }).build
      last_year = described_class.new(account: account, params: { span: 'last_year' }).build

      expect(this_year[:span]).to eq('this_year')
      expect(this_year[:months].pluck(:month)).to eq((1..10).map { |m| format('2026-%02d', m) })
      expect(last_year[:months].pluck(:month)).to eq((1..12).map { |m| format('2025-%02d', m) })
    end
  end
end
