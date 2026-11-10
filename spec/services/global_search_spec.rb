# frozen_string_literal: true

require 'rails_helper'

# Buscar en todo (la lupa): contactos, organizaciones y casos, en todos sus campos.
RSpec.describe GlobalSearch do
  let(:account) { create(:account) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let!(:contact) do
    create(:contact, account: account, name: 'Mario Pérez', additional_attributes: { 'company_name' => 'Refrigeración del Norte' })
  end
  let!(:organization) { Organization.create!(account: account, name: 'Hielos SA', notes: 'Venden compresores industriales') }
  let!(:ticket) do
    CaseTicket.create!(account: account, contact: contact, case_type: soporte, title: 'Falla de enfriamiento',
                       description: 'El compresor hace mucho ruido desde el lunes')
  end

  def search(query, grant: admin, **opts)
    described_class.new(account: account, grant: grant, query: query, **opts).call
  end

  it 'encuentra la palabra en cualquier campo, sin acentos ni mayúsculas' do
    result = search('COMPRESOR')
    expect(result[:organizations][:items].pluck(:id)).to eq([organization.id])
    expect(result[:cases][:items].pluck(:id)).to eq([ticket.id])
    expect(search('refrigeracion')[:contacts][:items].pluck(:id)).to eq([contact.id])
    expect(search('perez')[:contacts][:count]).to eq(1)
  end

  it 'dice en qué campo apareció y muestra el pedacito' do
    item = search('compresor')[:cases][:items].first
    expect(item[:match]).to eq(field: 'description', snippet: 'El compresor hace mucho ruido desde el lunes')
    expect(search('falla')[:cases][:items].first[:match]).to be_nil
  end

  it 'busca en los atributos personalizados (sus valores, no sus claves)' do
    ticket.update!(custom_attributes: { 'serie' => 'ZX-9981' })
    expect(search('zx-998')[:cases][:count]).to eq(1)
    expect(search('serie')[:cases][:count]).to eq(0)
  end

  it 'trae los datos de la segunda línea: organización, responsable y contacto' do
    user = create(:user, account: account, name: 'Lucía Ramos')
    contact.update!(organization: organization)
    organization.update!(owner_id: user.id)
    ticket.update!(assignee: user)

    expect(search('mario')[:contacts][:items].first).to include(organization: 'Hielos SA')
    expect(search('hielos')[:organizations][:items].first).to include(owner: 'Lucía Ramos')
    expect(search('enfriamiento')[:cases][:items].first).to include(assignee: 'Lucía Ramos', contact: 'Mario Pérez',
                                                                    type: 'Soporte')
  end

  it 'pide al menos 3 letras' do
    expect(search('ma')[:contacts]).to eq(count: 0, items: [])
  end

  it 'respeta los permisos' do
    grant = instance_double(Access::Grant, allowed?: false)
    allow(grant).to receive(:case_tickets, &:none)
    result = search('compresor', grant: grant)
    expect(result.values.pluck(:count)).to eq([0, 0, 0])
  end

  it 'con Clientes en «solo lo suyo» no muestra organizaciones ajenas' do
    grant = instance_double(Access::Grant, allowed?: true, own?: true, user_id: -1)
    allow(grant).to receive(:contacts, &:none)
    allow(grant).to receive(:case_tickets, &:none)
    expect(search('hielos', grant: grant)[:organizations][:count]).to eq(0)
    organization.update!(owner_id: create(:user, account: account).id)
    mine = instance_double(Access::Grant, allowed?: true, own?: true, user_id: organization.owner_id)
    allow(mine).to receive(:contacts, &:none)
    allow(mine).to receive(:case_tickets, &:none)
    expect(search('hielos', grant: mine)[:organizations][:count]).to eq(1)
  end

  it '«ver más» trae un solo grupo, paginado' do
    result = search('compresor', type: 'cases', page: 1)
    expect(result.keys).to eq([:cases])
  end
end
