# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones — ligar por primera vez y «Cambiar de organización».
RSpec.describe Organizations::ChangeContactOrganization do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:acme) { account.organizations.create!(name: 'Acme') }
  let(:globex) { account.organizations.create!(name: 'Globex') }
  let(:luis) { create(:contact, account: account, name: 'Luis') }
  let(:ana) { create(:contact, account: account, name: 'Ana', organization: acme) }
  let(:iguala) { account.contract_types.create!(name: 'Iguala') }

  before { CaseSetting.for_account(account).update!(organization_rules: {}) }

  def contract(contact, status: :active)
    account.contracts.create!(contact: contact, contract_type: iguala, title: 'Iguala', price: 1,
                              starts_on: Date.current, status: status)
  end

  it 'al ligarlo por primera vez, lo que no tenía organización pasa a ella' do
    viejo = contract(luis)
    luis.update!(organization: acme)
    expect(viejo.reload.organization_id).to eq(acme.id)
  end

  context 'when Luis is already in Acme' do
    let!(:activo) { luis.update!(organization: acme) && contract(luis) }
    let!(:cancelado) { contract(luis, status: :cancelled) }

    it '«pasar todo»: lo suyo se va a la nueva, sin sustituto' do
      described_class.new(contact: luis, to: globex, move: true, user: user).call
      expect([activo.reload.organization_id, cancelado.reload.organization_id]).to eq([globex.id, globex.id])
      expect(luis.reload.organization).to eq(globex)
      expect(acme.events.last).to have_attributes(action: 'contact_left')
      expect(globex.events.last.data).to include('moved' => true, 'from' => 'Acme')
    end

    it '«no pasar»: se queda en Acme, lo vivo pasa al sustituto y lo cerrado sigue con Luis' do
      described_class.new(contact: luis, to: globex, move: false, user: user, substitute: { contact: ana }).call
      expect(activo.reload).to have_attributes(organization_id: acme.id, contact_id: ana.id)
      expect(cancelado.reload).to have_attributes(organization_id: acme.id, contact_id: luis.id)
      expect(acme.events.last.data).to include('replacement_name' => 'Ana', 'to' => 'Globex')
    end

    it '«no pasar» sin nadie más en Acme: da de alta al sustituto ahí' do
      described_class.new(contact: luis, to: globex, move: false, user: user,
                          substitute: { new_contact: { name: 'Pedro', email: 'pedro@acme.mx' } }).call
      pedro = account.contacts.from_email('pedro@acme.mx')
      expect(pedro.organization).to eq(acme)
      expect(activo.reload.contact).to eq(pedro)
    end

    it 'sin sustituto, o con uno de otra organización, no deja' do
      expect { described_class.new(contact: luis, to: globex, move: false, user: user).call }
        .to raise_error(described_class::Error)
      otro = create(:contact, account: account, organization: globex)
      expect { described_class.new(contact: luis, to: globex, move: false, user: user, substitute: { contact: otro }).call }
        .to raise_error(described_class::Error)
      expect(luis.reload.organization).to eq(acme)
    end
  end
end
