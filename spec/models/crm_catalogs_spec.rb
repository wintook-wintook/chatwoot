# frozen_string_literal: true

require 'rails_helper'

# CrmZeus O0 — catálogos de organizaciones (nombre único, un solo predeterminado, plazos).
RSpec.describe 'CrmZeus catálogos' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }

  describe CrmLookup do
    it 'el nombre es único por catálogo, sin importar mayúsculas' do
      account.crm_lookups.create!(kind: :industry, name: 'Ferretería')
      expect(account.crm_lookups.build(kind: :industry, name: ' FERRETERÍA ')).not_to be_valid
      expect(account.crm_lookups.build(kind: :origin, name: 'Ferretería')).to be_valid
    end

    it 'deja un solo predeterminado por catálogo' do
      first = account.crm_lookups.create!(kind: :origin, name: 'Otro', is_default: true)
      zone = account.crm_lookups.create!(kind: :zone, name: 'Norte', is_default: true)
      account.crm_lookups.create!(kind: :origin, name: 'Referido', is_default: true)

      expect(first.reload).not_to be_is_default
      expect(zone.reload).to be_is_default
    end
  end

  describe CrmPaymentTerm do
    it 'sin plazos es contado y con plazos deben sumar 100 %' do
      expect(account.crm_payment_terms.create!(name: 'Contado').credit_days).to eq(0)

      three = account.crm_payment_terms.build(name: '3 pagos', installments_attributes: [
                                                { days: 0, percent: 30 }, { days: 15, percent: 35 }, { days: 30, percent: 30 }
                                              ])
      expect(three).not_to be_valid

      three.installments.last.percent = 35
      three.save!
      expect(three.credit_days).to eq(30)
      expect(three.installments.map(&:account_id).uniq).to eq([account.id])
    end
  end

  describe CrmCurrency do
    it 'normaliza la clave ISO y la moneda local no lleva tipo de cambio fijo' do
      peso = account.crm_currencies.create!(name: 'Peso', iso_code: 'mxn', is_local: true, fixed_exchange_rate: 5)
      expect(peso.iso_code).to eq('MXN')
      expect(peso.fixed_exchange_rate).to be_nil

      dollar = account.crm_currencies.create!(name: 'Dólar', iso_code: 'USD', fixed_exchange_rate: 20)
      expect(dollar.fixed_exchange_rate).to eq(20)
    end
  end

  describe CrmSeller do
    it 'se puede ligar a un agente de la cuenta, pero no a uno de otra' do
      agent = create(:user, account: account)
      outsider = create(:user)

      expect(account.crm_sellers.create!(name: 'Alberto', user: agent).user).to eq(agent)
      expect(account.crm_sellers.create!(name: 'CAJERO').user).to be_nil
      expect(account.crm_sellers.build(name: 'Ajeno', user: outsider)).not_to be_valid
    end
  end

  describe Crm::DefaultCatalogs do
    it 'precarga México con 32 estados, peso y contado una sola vez' do
      2.times { described_class.ensure!(account) }

      mexico = account.crm_countries.sole
      expect(mexico.name).to eq('México')
      expect(mexico.states.count).to eq(32)
      expect(mexico.states.find_by(abbreviation: 'COA').name).to eq('Coahuila')
      expect(account.crm_currencies.sole).to have_attributes(iso_code: 'MXN', is_local: true, is_default: true)
      expect(account.crm_payment_terms.sole.name).to eq('Contado')
    end

    it 'no toca lo que la cuenta ya tiene' do
      account.crm_currencies.create!(name: 'Dólar', iso_code: 'USD')
      described_class.ensure!(account)
      expect(account.crm_currencies.pluck(:iso_code)).to eq(['USD'])
    end
  end
end
