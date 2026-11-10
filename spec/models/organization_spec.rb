# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O1 — etapa (prospecto/cliente) y tipo (empresa/público en general) aparte.
RSpec.describe Organization do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  it 'pasar a cliente solo cambia la etapa, guarda la fecha y lo anota en la bitácora' do
    org = account.organizations.create!(name: 'Acme', tax_id: 'acm010101aaa')
    contact = create(:contact, account: account, organization: org)
    expect(org).to have_attributes(stage: 'prospect', kind: 'company', tax_id: 'ACM010101AAA')
    expect(org.became_prospect_at).to be_present

    org.change_stage!(:customer, user)
    expect(org.reload).to be_customer
    expect(org.became_customer_at).to be_present
    expect(contact.reload.organization).to eq(org)
    expect(org.events.last).to have_attributes(user: user, action: 'stage', data: { 'from' => 'prospect', 'to' => 'customer' })
  end

  it 'público en general no guarda RFC' do
    org = account.organizations.create!(name: 'Ana López', kind: :general_public, tax_id: 'XAXX010101000')
    expect(org.tax_id).to be_nil
  end

  it 'desde un contacto usa su empresa escrita o, sin ella, público en general con su nombre' do
    con_empresa = create(:contact, account: account, name: 'Luis', email: 'luis@acme.mx',
                                   additional_attributes: { 'company_name' => 'Acme SA' })
    sin_empresa = create(:contact, account: account, name: 'Ana López')
    expect(described_class.build_for(con_empresa)).to have_attributes(name: 'Acme SA', kind: 'company',
                                                                      email_domain: 'acme.mx')
    expect(described_class.build_for(sin_empresa)).to have_attributes(name: 'Ana López', kind: 'general_public')
  end

  it 'no repite RFC en la cuenta y no acepta contactos de otra cuenta' do
    account.organizations.create!(name: 'Acme', tax_id: 'ACM010101AAA')
    expect(account.organizations.new(name: 'Otra', tax_id: 'acm010101aaa')).not_to be_valid
    otra = create(:account).organizations.create!(name: 'Ajena')
    expect(create(:contact, account: account).update(organization: otra)).to be(false)
  end

  it 'al borrarla, sus contactos quedan sin organización' do
    org = account.organizations.create!(name: 'Acme')
    contact = create(:contact, account: account, organization: org)
    org.destroy!
    expect(contact.reload.organization_id).to be_nil
  end
end
