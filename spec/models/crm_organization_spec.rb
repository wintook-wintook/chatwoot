# frozen_string_literal: true

require 'rails_helper'

# CrmZeus O0 — organización (cliente / prospecto), con las reglas de CRMZeus.
RSpec.describe CrmOrganization do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  def organization(attrs = {})
    account.crm_organizations.create!({ legal_name: 'Aceros del Norte SA de CV', trade_name: 'Aceros del Norte' }.merge(attrs))
  end

  it 'nace como prospecto activo con el mínimo: razón social y nombre comercial' do
    record = organization
    expect(record).to be_prospect
    expect(record).to be_status_active
    expect(record.organization_type_before_type_cast).to eq(2)
  end

  it 'limpia espacios y deja clave y RFC en mayúsculas' do
    record = organization(legal_name: '  Aceros   del Norte ', key: ' c-001 ', tax_id: 'ano010101ab1', email: ' Ventas@Aceros.MX ')
    expect(record.legal_name).to eq('Aceros del Norte')
    expect(record.key).to eq('C-001')
    expect(record.tax_id).to eq('ANO010101AB1')
    expect(record.email).to eq('ventas@aceros.mx')
  end

  describe 'no se repiten razón social, nombre comercial ni clave entre clientes y prospectos' do
    before { organization(organization_type: :customer, key: 'C-001') }

    it 'rechaza la misma razón social sin importar mayúsculas' do
      dup = account.crm_organizations.build(legal_name: 'ACEROS DEL NORTE SA DE CV', trade_name: 'Otro')
      expect(dup).not_to be_valid
      expect(dup.errors[:legal_name]).to include(described_class::DUPLICATE_MESSAGE)
    end

    it 'rechaza el mismo nombre comercial y la misma clave' do
      dup = account.crm_organizations.build(legal_name: 'Otra', trade_name: 'aceros del norte', key: 'c-001')
      expect(dup).not_to be_valid
      expect(dup.errors.attribute_names).to include(:trade_name, :key)
    end

    it 'permite varias organizaciones sin clave' do
      organization(legal_name: 'Uno', trade_name: 'Uno')
      expect { organization(legal_name: 'Dos', trade_name: 'Dos') }.not_to raise_error
    end

    it 'en otra cuenta sí se puede repetir' do
      record = other_account.crm_organizations.build(legal_name: 'Aceros del Norte SA de CV', trade_name: 'Aceros del Norte', key: 'C-001')
      expect(record).to be_valid
    end
  end

  it 'borra fecha y causa de suspensión si el estatus es activo' do
    record = organization(status: :credit_suspended, suspended_on: Date.new(2026, 10, 1), suspension_reason: 'Adeudo')
    expect(record.suspended_on).to eq(Date.new(2026, 10, 1))

    record.update!(status: :active)
    expect(record.suspended_on).to be_nil
    expect(record.suspension_reason).to be_nil
  end

  it 'convierte un prospecto en cliente conservando el id' do
    record = organization
    id = record.id
    record.convert_to_customer!

    expect(record.reload).to be_customer
    expect(record.id).to eq(id)
    expect(record.converted_at).to be_present
    expect { record.convert_to_customer! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  describe 'catálogos' do
    let(:rating) { account.crm_lookups.create!(kind: :rating, name: 'Cliente Oro') }
    let(:zone) { account.crm_lookups.create!(kind: :zone, name: 'Zona Norte') }

    it 'acepta un valor del catálogo correcto' do
      expect(organization(rating: rating, zone: zone).rating.name).to eq('Cliente Oro')
    end

    it 'rechaza un valor de otro catálogo (una zona como calificación)' do
      record = account.crm_organizations.build(legal_name: 'X', trade_name: 'X', rating: zone)
      expect(record).not_to be_valid
      expect(record.errors[:rating]).to be_present
    end

    it 'rechaza catálogos, vendedor y moneda de otra cuenta' do
      foreign_rating = other_account.crm_lookups.create!(kind: :rating, name: 'Ajeno')
      foreign_seller = other_account.crm_sellers.create!(name: 'Ajeno')
      record = account.crm_organizations.build(legal_name: 'X', trade_name: 'X', rating: foreign_rating, seller: foreign_seller)
      expect(record).not_to be_valid
      expect(record.errors.attribute_names).to include(:rating, :seller)
    end
  end

  it 'busca por razón social, nombre comercial o clave' do
    organization(key: 'C-777')
    organization(legal_name: 'Ferretería La Paz', trade_name: 'La Paz')
    expect(account.crm_organizations.search('norte').count).to eq(1)
    expect(account.crm_organizations.search('c-777').count).to eq(1)
    expect(account.crm_organizations.search('').count).to eq(2)
  end
end
