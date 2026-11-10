# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O4 — asistente para los contactos que ya existían.
RSpec.describe Organizations::Suggestions do
  let(:account) { create(:account) }
  let(:service) { described_class.new(account: account, contacts: account.contacts) }
  let(:iguala) { account.contract_types.create!(name: 'Iguala') }

  before { CaseSetting.for_account(account).update!(organization_rules: {}) }

  it 'agrupa por empresa escrita o dominio (no correo gratuito) y propone cliente si hay contrato' do
    luis = create(:contact, account: account, email: 'luis@acme.mx', additional_attributes: { 'company_name' => 'Acme S.A. de C.V.' })
    ana = create(:contact, account: account, email: 'ana@otra.mx', additional_attributes: { 'company_name' => 'ACME SA de CV' })
    beto = create(:contact, account: account, email: 'beto@globex.com')
    create(:contact, account: account, email: 'pepe@gmail.com')
    casa = create(:contact, account: account, name: 'Casa Pérez', email: 'casa@gmail.com')
    account.contracts.create!(contact: casa, contract_type: iguala, title: 'Monitoreo', price: 1, starts_on: Date.current)

    suggestions = service.call
    expect(suggestions.size).to eq(3)
    acme = suggestions.find { |s| s[:source] == :company }
    expect(acme[:contacts].pluck('id')).to contain_exactly(luis.id, ana.id)
    expect(suggestions.find { |s| s[:source] == :domain }).to include(name: 'globex.com', email_domain: 'globex.com')
    expect(suggestions.find { |s| s[:source] == :person }).to include(name: 'Casa Pérez', kind: 'general_public',
                                                                      stage: 'customer')
    expect(suggestions.first[:stage]).to eq('customer')
    expect(beto.reload.organization_id).to be_nil
  end

  it 'aplica solo lo confirmado y liga a una organización existente con el mismo nombre' do
    existing = account.organizations.create!(name: 'Acme')
    luis = create(:contact, account: account, additional_attributes: { 'company_name' => 'acme' })
    beto = create(:contact, account: account, email: 'beto@globex.com')
    acme = service.call.find { |s| s[:source] == :company }
    expect(acme[:existing_organization_id]).to eq(existing.id)

    result = service.apply([acme.slice(:name, :kind, :stage, :existing_organization_id)
                                .merge(contact_ids: [luis.id])], nil)
    expect(result).to eq(created: 0, linked: 1)
    expect(luis.reload.organization).to eq(existing)
    expect(beto.reload.organization_id).to be_nil
  end
end
