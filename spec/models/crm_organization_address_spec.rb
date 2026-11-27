# frozen_string_literal: true

require 'rails_helper'

# CrmZeus O0 — domicilio (dirección principal) y consignatarios de una organización.
RSpec.describe CrmOrganizationAddress do
  let(:account) { create(:account) }
  let(:torreon) do
    coahuila = account.crm_countries.first.states.find_by!(abbreviation: 'COA')
    coahuila.cities.create!(name: 'Torreón')
  end
  let(:organization) { account.crm_organizations.create!(legal_name: 'Aceros del Norte SA', trade_name: 'Aceros del Norte') }

  before { Crm::DefaultCatalogs.ensure!(account) }

  def consignee(attrs = {})
    organization.consignees.create!({ consignee_name: 'Bodega Sur', street: 'Calle 5' }.merge(attrs))
  end

  it 'el domicilio se captura con la organización y hereda cuenta y razón social' do
    record = account.crm_organizations.create!(legal_name: 'Ferretería La Paz SA', trade_name: 'La Paz',
                                               home_address_attributes: { street: 'Av. Juárez', city_id: torreon.id })
    home = record.home_address
    expect(home).to be_is_primary
    expect(home.account_id).to eq(account.id)
    expect(home.consignee_name).to eq('Ferretería La Paz SA')
    expect(record.consignees).to be_empty
  end

  it 'editar el domicilio desde la organización no crea otro' do
    organization.update!(home_address_attributes: { street: 'Av. Juárez' })
    organization.update!(home_address_attributes: { street: 'Av. Morelos' })
    expect(organization.addresses.count).to eq(1)
    expect(organization.reload.home_address.street).to eq('Av. Morelos')
  end

  it 'los consignatarios no son el domicilio y no hay dos domicilios' do
    organization.update!(home_address_attributes: { street: 'Av. Juárez' })
    expect(consignee).not_to be_is_primary
    expect(organization.consignees.count).to eq(1)

    second_home = organization.addresses.build(street: 'Otra', is_primary: true)
    expect(second_home).not_to be_valid
    expect(second_home.errors[:is_primary]).to be_present
  end

  it 'solo una dirección es «para facturar»' do
    organization.update!(home_address_attributes: { street: 'Av. Juárez', for_billing: true })
    consignee(for_billing: true)
    expect(organization.reload.home_address).not_to be_for_billing
    expect(organization.consignees.first).to be_for_billing
  end

  it 'el domicilio no se borra suelto, pero sí con la organización' do
    organization.update!(home_address_attributes: { street: 'Av. Juárez' })
    consignee
    expect(organization.home_address.destroy).to be(false)
    expect { organization.consignees.first.destroy! }.not_to raise_error

    expect { organization.destroy! }.to change(described_class, :count).by(-1)
  end

  it 'arma la dirección completa con ciudad, estado y país' do
    record = consignee(street: 'Av. Juárez', exterior_number: '123', interior_number: '4', neighborhood: 'Centro',
                       city: torreon, postal_code: '27000')
    expect(record.full_address).to eq('Av. Juárez 123 Int 4, Centro, Torreón, COA, México, CP 27000')
  end

  it 'rechaza una ciudad de otra cuenta' do
    other = create(:account)
    Crm::DefaultCatalogs.ensure!(other)
    foreign_city = other.crm_countries.first.states.first.cities.create!(name: 'Ajena')
    record = organization.consignees.build(street: 'X', city: foreign_city)
    expect(record).not_to be_valid
    expect(record.errors[:city]).to be_present
  end
end
