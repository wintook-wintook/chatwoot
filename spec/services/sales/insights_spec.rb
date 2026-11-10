# frozen_string_literal: true

require 'rails_helper'

# Dali D5a — las cifras de ventas que explica el asistente, con los permisos de quien pregunta.
RSpec.describe Sales::Insights do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator, name: 'Dueña') }
  let(:ana)     { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:luis)    { create(:user, account: account, role: :agent, name: 'Luis') }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }

  def grant(user) = Access::Grant.for(account.account_users.find_by(user: user))

  def insights(user) = described_class.new(account: account, user: user, grant: grant(user))

  def deal(user, amount, outcome: nil, at: nil, **attrs)
    ticket = CaseTicket.create!(account: account, title: "Trato #{amount}", contact: contact, case_type: venta, assignee: user)
    ticket.update_columns({ amount: amount, currency: 'MXN' }.merge(attrs)) # rubocop:disable Rails/SkipsModelValidations
    ticket.update_columns(outcome: CaseTicket.outcomes[outcome], outcome_at: at, status: CaseTicket.statuses[:closed]) if outcome # rubocop:disable Rails/SkipsModelValidations
    ticket
  end

  def with_sales_level(user, level)
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    role.update!(areas: role.areas.merge('sales' => level))
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  before do
    travel_to(Time.zone.local(2026, 11, 15, 12))
    deal(ana, 100_000, outcome: :won, at: Time.zone.local(2026, 11, 3))
    deal(luis, 40_000, outcome: :won, at: Time.zone.local(2026, 11, 5))
    deal(luis, 10_000, outcome: :lost, at: Time.zone.local(2026, 11, 6))
    deal(ana, 30_000, outcome: :won, at: Time.zone.local(2026, 10, 10))
    SalesBudgetLine.create!(account: account, user: ana, period: Date.new(2026, 11, 1), amount: 200_000)
  end

  it 'el dueño ve el mes de todos, contra el periodo anterior y la meta' do
    data = insights(admin).overview(period: 'this_month')

    expect(data[:won]).to eq('MXN' => 140_000.0)
    expect(data[:won_deals]).to eq(2)
    expect(data[:win_rate]).to eq(66.7)
    expect(data[:compare][:won]).to eq('MXN' => 30_000.0)
    expect(data[:budget][:by_currency].first).to include(budget: 200_000.0, actual: 140_000.0, percent: 70.0, missing: 60_000.0)
    expect(data[:budget][:elapsed_percent]).to be_between(40, 60)
  end

  it 'con «solo lo suyo» el vendedor solo ve lo suyo, aunque pida a otro' do
    with_sales_level(luis, 'own')

    data = insights(luis).overview(period: 'this_month', seller_id: ana.id)

    expect(data[:seller]).to eq('Luis')
    expect(data[:won]).to eq('MXN' => 40_000.0)
    expect(insights(luis).breakdown(dimension: 'seller')[:rows].pluck(:name)).to eq(['Luis'])
  end

  it 'sin acceso a Ventas no consulta nada' do
    with_sales_level(luis, 'none')

    expect { insights(luis) }.to raise_error(described_class::Denied)
  end

  it 'ranking por vendedor con su tasa de cierre, y por cliente' do
    rows = insights(admin).breakdown(dimension: 'seller', period: 'this_month')[:rows]
    expect(rows.map { |r| r.slice(:name, :won_total, :win_rate) }).to eq(
      [{ name: 'Ana', won_total: 100_000.0, win_rate: 100.0 }, { name: 'Luis', won_total: 40_000.0, win_rate: 50.0 }]
    )
    expect(insights(admin).breakdown(dimension: 'client')[:rows].first).to include(name: 'Acme', won_total: 140_000.0, deals: 2)
  end

  it 'tratos para actuar: lo que cierra este mes y los compromisos vencidos' do
    deal(ana, 70_000, expected_close_at: Date.new(2026, 11, 28), probability: 50)
    deal(ana, 20_000, expected_close_at: Date.new(2026, 11, 2), committed_at: 1.week.ago)

    expect(insights(admin).deals(filter: 'closing_this_month')[:deals].pluck(:amount)).to eq([70_000.0, 20_000.0])
    expect(insights(admin).pipeline_health[:committed_overdue].pluck(:amount)).to eq([20_000.0])
    progress = insights(admin).budget_progress(period: 'this_month')
    expect(progress[:can_close_gap].pluck(:amount)).to eq([70_000.0])
    expect(progress[:sellers].first).to include(name: 'Ana', percent: 50.0)
  end
end
