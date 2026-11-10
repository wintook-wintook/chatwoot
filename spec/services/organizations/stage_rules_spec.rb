# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O3 — prospecto y cliente automáticos según Parámetros de ventas.
RSpec.describe Organizations::StageRules do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Luis', additional_attributes: { 'company_name' => 'Acme' }) }
  let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:iguala) { account.contract_types.create!(name: 'Iguala') }

  def rules(values)
    CaseSetting.for_account(account).update!(organization_rules: values)
  end

  def opportunity
    CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta, status: :in_progress)
  end

  it 'las cuentas nuevas nacen con oportunidad → prospecto y ganada/contrato → cliente encendidos' do
    expect(CaseSetting.for_account(account).organization_rules).to include(
      'prospect_on_opportunity' => true, 'customer_on_won' => true, 'customer_on_contract' => true,
      'prospect_on_quote_sent' => false, 'customer_on_quote_accepted' => false
    )
  end

  it 'una oportunidad nueva hace prospecto al contacto; ganarla lo pasa a cliente con motivo en la bitácora' do
    ticket = opportunity
    org = contact.reload.organization
    expect(org).to have_attributes(name: 'Acme', stage: 'prospect', kind: 'company')
    expect(ticket.reload.organization_id).to eq(org.id)

    ticket.update!(outcome: :won, outcome_at: Time.current)
    expect(org.reload).to be_customer
    expect(org.events.order(:id).last.data).to include('to' => 'customer', 'reason' => 'customer_on_won')
  end

  it 'un contrato nuevo crea la organización ya como cliente si no tenía' do
    account.contracts.create!(contact: contact, contract_type: iguala, title: 'Iguala', price: 1, starts_on: Date.current)
    expect(contact.reload.organization).to have_attributes(stage: 'customer')
  end

  it 'con las reglas apagadas (cuentas que ya existían) no hace nada' do
    rules({})
    opportunity
    account.contracts.create!(contact: contact, contract_type: iguala, title: 'Iguala', price: 1, starts_on: Date.current)
    expect(contact.reload.organization).to be_nil
  end

  it 'cotización enviada → prospecto y aceptada → cliente, si se encienden' do
    rules(prospect_on_quote_sent: true, customer_on_quote_accepted: true)
    quote = account.quotes.create!(contact: contact)
    Quotes::StatusService.new(quote).apply!('sent')
    org = contact.reload.organization
    expect(org).to have_attributes(stage: 'prospect')
    expect(quote.reload.organization_id).to eq(org.id)

    Quotes::StatusService.new(quote.reload).apply!('won')
    expect(org.reload).to be_customer
  end

  it 'nunca regresa un cliente a prospecto' do
    org = account.organizations.create!(name: 'Acme', stage: :customer)
    contact.update!(organization: org)
    opportunity
    expect(org.reload).to be_customer
  end

  it 'el contacto sin responsable propio hereda el de su organización' do
    owner = create(:user, account: account)
    org = account.organizations.create!(name: 'Acme', owner: owner)
    contact.update!(organization: org)
    expect(contact.effective_owner_id).to eq(owner.id)
    expect(opportunity.assignee_id).to eq(owner.id)
  end
end
