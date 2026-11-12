# frozen_string_literal: true

require 'rails_helper'

# Presupuesto de ventas — lo logrado se cuenta por trato, sin IVA y una sola vez.
RSpec.describe Sales::Actuals do
  let(:account) { create(:account) }
  let(:seller)  { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:month)   { Date.new(2026, 11, 1) }

  def opportunity(amount:, at: Time.zone.local(2026, 11, 10), outcome: :won, user: seller, currency: 'MXN')
    ticket = CaseTicket.create!(account: account, title: 'Trato', contact: contact, case_type: venta, assignee: user)
    ticket.update_columns(amount: amount, currency: currency, outcome: CaseTicket.outcomes[outcome], outcome_at: at) # rubocop:disable Rails/SkipsModelValidations
    ticket
  end

  def quote(status:, subtotal:, discount: 0, opportunity: nil, at: Time.zone.local(2026, 11, 12), user: seller) # rubocop:disable Metrics/ParameterLists
    record = Quote.create!(account: account, contact: contact, assignee: user, opportunity: opportunity)
    record.update_columns(status: Quote.statuses[status], subtotal: subtotal, discount_total: discount, # rubocop:disable Rails/SkipsModelValidations
                          tax_total: (subtotal - discount) * 0.16, total: (subtotal - discount) * 1.16, decided_at: at)
    record
  end

  def rows(user_ids: nil)
    described_class.new(account: account, from: month, to: month, currency: 'MXN', user_ids: user_ids).rows
  end

  it 'oportunidad sin cotización: su monto' do
    opportunity(amount: 50_000)

    expect(rows).to contain_exactly(include(user_id: seller.id, organization_id: organization.id, amount: 50_000, period: month))
  end

  it 'oportunidad con cotización ganada: la cotización sin IVA, una sola vez; las demás no cuentan' do
    deal = opportunity(amount: 104_400) # la oportunidad copió el total con IVA
    quote(status: :won, subtotal: 100_000, discount: 10_000, opportunity: deal)
    quote(status: :cancelled, subtotal: 120_000, opportunity: deal)

    expect(rows.pluck(:amount)).to eq([90_000])
  end

  it 'cotización suelta ganada cuenta con su vendedor y fecha de decisión' do
    quote(status: :won, subtotal: 30_000, user: other)
    quote(status: :sent, subtotal: 99_000)

    expect(rows).to contain_exactly(include(user_id: other.id, amount: 30_000))
  end

  it 'deja fuera lo perdido, lo de otro mes, otra moneda y otros vendedores si se filtra' do
    opportunity(amount: 1_000, outcome: :lost)
    opportunity(amount: 2_000, at: Time.zone.local(2026, 10, 31))
    opportunity(amount: 3_000, currency: 'USD')
    opportunity(amount: 4_000, user: other)

    expect(rows(user_ids: [seller.id])).to be_empty
    expect(rows.pluck(:amount)).to eq([4_000])
  end
end
