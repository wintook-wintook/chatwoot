# frozen_string_literal: true

require 'rails_helper'

# Presupuesto de ventas — etapa 1: metas por vendedor y vendedor + cliente, su avance,
# y elegir la cotización aceptada al ganar (es la que cuenta como lo logrado).
RSpec.describe 'Sales Budgets API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:seller)  { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:other)   { create(:user, account: account, role: :agent, name: 'Luis') }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:api)     { "/api/v1/accounts/#{account.id}/sales_budgets" }
  let(:auth)    { admin.create_new_auth_token }

  def capture(lines, headers = auth)
    put "#{api}/bulk", params: { year: 2026, currency: 'MXN', lines: lines }, headers: headers, as: :json
  end

  def won_deal(user, amount, at = Time.zone.local(2026, 11, 5))
    ticket = CaseTicket.create!(account: account, title: 'Trato', contact: contact, case_type: venta, assignee: user)
    ticket.update_columns(amount: amount, currency: 'MXN', outcome: CaseTicket.outcomes[:won], outcome_at: at) # rubocop:disable Rails/SkipsModelValidations
  end

  def with_sales_level(user, level)
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    role.update!(areas: role.areas.merge('sales' => level))
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  describe 'captura' do
    it 'guarda, cambia y borra (0) metas por vendedor y por vendedor + cliente' do
      capture([{ user_id: seller.id, period: '2026-11', amount: 100_000 },
               { user_id: seller.id, organization_id: organization.id, period: '2026-11', amount: 40_000 }])
      capture([{ user_id: seller.id, period: '2026-11', amount: 120_000 }])

      get api, params: { year: 2026, kind: 'seller' }, headers: auth
      expect(response.parsed_body['lines'].pluck('amount')).to eq([120_000.0])
      get api, params: { year: 2026, kind: 'seller_client' }, headers: auth
      expect(response.parsed_body['lines'].first).to include('client_name' => 'Acme', 'amount' => 40_000.0)

      capture([{ user_id: seller.id, period: '2026-11', amount: 0 }])
      expect(account.sales_budget_lines.seller_only.count).to eq(0)
    end

    it 'quita un cliente de un vendedor en todo el año' do
      capture((1..3).map { |m| { user_id: seller.id, organization_id: organization.id, period: "2026-0#{m}", amount: 10 } })

      delete "#{api}/client", params: { year: 2026, user_id: seller.id, organization_id: organization.id }, headers: auth, as: :json

      expect(account.sales_budget_lines.count).to eq(0)
    end

    it 'copia un año a otro con ±% sin pisar lo ya capturado' do
      capture([{ user_id: seller.id, period: '2026-01', amount: 1000 }, { user_id: seller.id, period: '2026-02', amount: 2000 }])
      SalesBudgetLine.create!(account: account, user: seller, period: Date.new(2027, 2, 1), amount: 5)

      post "#{api}/copy", params: { from_year: 2026, to_year: 2027, percent: 10 }, headers: auth, as: :json

      expect(response.parsed_body['copied']).to eq(1)
      expect(account.sales_budget_lines.in_year(2027).order(:period).pluck(:amount)).to eq([1100, 5])
    end

    it 'solo captura quien tiene Ventas en «Todo»' do
      with_sales_level(seller, 'view')

      capture([{ user_id: seller.id, period: '2026-11', amount: 1 }], seller.create_new_auth_token)

      expect(response).to have_http_status(:forbidden)
      get api, params: { year: 2026 }, headers: seller.create_new_auth_token
      expect(response.parsed_body['can_capture']).to be(false)
    end

    it 'no acepta vendedores ni clientes de otra cuenta' do
      ajeno = create(:user)

      capture([{ user_id: ajeno.id, period: '2026-11', amount: 1 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(SalesBudgetLine.count).to eq(0)
    end
  end

  describe 'avance' do
    before do
      capture([{ user_id: seller.id, period: '2026-11', amount: 100_000 },
               { user_id: seller.id, organization_id: organization.id, period: '2026-11', amount: 40_000 },
               { user_id: other.id, period: '2026-11', amount: 50_000 }])
      won_deal(seller, 30_000)
      won_deal(other, 60_000)
    end

    it 'meta contra lo logrado por vendedor, sus clientes y otros clientes' do
      get "#{api}/report", params: { from: '2026-11', to: '2026-11' }, headers: auth
      body = response.parsed_body

      expect(body['totals']).to include('budget' => 150_000.0, 'actual' => 90_000.0)
      ana = body['sellers'].find { |s| s['name'] == 'Ana' }
      expect(ana).to include('budget' => 100_000.0, 'actual' => 30_000.0, 'percent' => 30.0, 'diff' => -70_000.0, 'other_actual' => 0.0)
      expect(ana['clients'].first).to include('name' => 'Acme', 'budget' => 40_000.0, 'actual' => 30_000.0)
      expect(body['months']).to eq([{ 'period' => '2026-11', 'budget' => 150_000.0, 'actual' => 90_000.0 }])
    end

    it 'con Ventas en «solo lo suyo» el vendedor ve solo lo propio' do
      with_sales_level(seller, 'own')

      get "#{api}/report", params: { from: '2026-11', to: '2026-11' }, headers: seller.create_new_auth_token

      expect(response.parsed_body['sellers'].pluck('name')).to eq(['Ana'])
      expect(response.parsed_body['totals']['actual']).to eq(30_000.0)
    end
  end

  describe 'ganar con varias cotizaciones' do
    let(:deal) { CaseTicket.create!(account: account, title: 'Trato', contact: contact, case_type: venta, assignee: seller) }

    before do
      2.times { Quote.create!(account: account, contact: contact, assignee: seller, opportunity: deal, status: :sent) }
    end

    it 'exige elegir cuál aceptó el cliente; con la elegida se gana' do
      patch "/api/v1/accounts/#{account.id}/case_tickets/#{deal.id}/outcome", params: { outcome: 'won' }, headers: auth, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['quotes'].size).to eq(2)
      expect(deal.reload.outcome).to be_nil

      chosen = deal.quotes.first
      patch "/api/v1/accounts/#{account.id}/case_tickets/#{deal.id}/outcome", params: { outcome: 'won', accepted_quote_id: chosen.id },
                                                                              headers: auth, as: :json
      expect(response).to have_http_status(:ok)
      expect(chosen.reload).to be_won
      expect(deal.quotes.where.not(id: chosen.id).first).to be_cancelled
    end
  end
end
