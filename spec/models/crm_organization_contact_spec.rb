# frozen_string_literal: true

require 'rails_helper'

# CrmZeus C0 — liga entre contactos de Wintook y organizaciones de CrmZeus.
RSpec.describe CrmOrganizationContact do
  let(:account) { create(:account) }
  let(:organization) { account.crm_organizations.create!(legal_name: 'Aceros del Norte SA', trade_name: 'Aceros') }
  let(:other_organization) { account.crm_organizations.create!(legal_name: 'Pinturas SA', trade_name: 'Pinturas') }
  let(:ana) { create(:contact, account: account, name: 'Ana') }
  let(:beto) { create(:contact, account: account, name: 'Beto') }

  it 'una organización tiene varios contactos y toma la cuenta de la organización' do
    link = organization.contact_links.create!(contact: ana)
    organization.contact_links.create!(contact: beto)
    expect(link.account).to eq(account)
    expect(organization.contacts).to contain_exactly(ana, beto)
  end

  it 'un contacto solo pertenece a una organización y el error la nombra' do
    organization.contact_links.create!(contact: ana)
    row = other_organization.contact_links.new(contact: ana)
    expect(row).not_to be_valid
    expect(row.errors[:contact].first).to eq('ya pertenece a «Aceros»')
  end

  it 'rechaza un contacto de otra cuenta' do
    row = organization.contact_links.new(contact: create(:contact))
    expect(row).not_to be_valid
    expect(row.errors[:contact]).to include('no pertenece a la cuenta')
  end

  it 'borrar la organización o la liga no borra al contacto' do
    organization.contact_links.create!(contact: ana).destroy!
    organization.contact_links.create!(contact: ana)
    organization.destroy!
    expect(Contact.exists?(ana.id)).to be(true)
    expect(described_class.where(account: account)).to be_empty
  end

  it 'borrar al contacto borra su liga' do
    organization.contact_links.create!(contact: ana)
    ana.destroy!
    expect(organization.contact_links.reload).to be_empty
  end
end
