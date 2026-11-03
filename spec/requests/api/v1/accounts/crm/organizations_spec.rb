# frozen_string_literal: true

require 'rails_helper'

# CrmZeus O1 — API de organizaciones y consignatarios.
RSpec.describe 'CrmZeus Organizations API' do
  let(:account) { create(:account, locale: 'es') } # como las cuentas reales: los errores salen en español
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/crm/organizations" }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def organization(attrs = {})
    account.crm_organizations.create!({ legal_name: 'Aceros del Norte SA', trade_name: 'Aceros del Norte' }.merge(attrs))
  end

  describe 'lista' do
    before do
      organization(organization_type: :customer, created_by: admin)
      organization(legal_name: 'Ferretería La Paz SA', trade_name: 'La Paz')
      organization(legal_name: 'Gimnasio Fit SA', trade_name: 'Fit', organization_type: :customer)
    end

    it 'filtra por tipo y búsqueda, y cuenta por pestaña' do
      get url, params: { type: 'customer' }, headers: admin.create_new_auth_token, as: :json
      body = response.parsed_body
      expect(body['organizations'].pluck('trade_name')).to eq(['Aceros del Norte', 'Fit'])
      expect(body['meta']['counts']).to eq('customer' => 2, 'prospect' => 1, 'all' => 3)

      get url, params: { q: 'paz' }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['organizations'].pluck('trade_name')).to eq(['La Paz'])
    end

    it 'el Vendedor («solo las mías» en Ventas) ve todas y puede editar' do
      give_role(agent, 'seller')
      get url, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['meta']['count']).to eq(3)
      expect(response.parsed_body['meta']['can_edit']).to be(true)
    end

    it 'trae cuántos contactos tiene ligados cada organización' do
      aceros = account.crm_organizations.find_by(trade_name: 'Aceros del Norte')
      2.times { |i| aceros.contact_links.create!(contact: create(:contact, account: account, email: "c#{i}@aceros.mx")) }
      get url, headers: admin.create_new_auth_token, as: :json
      counts = response.parsed_body['organizations'].to_h { |org| [org['trade_name'], org['contacts_count']] }
      expect(counts).to eq('Aceros del Norte' => 2, 'Fit' => 0, 'La Paz' => 0)
    end

    it 'sin Ventas (Técnico) no entra' do
      give_role(agent, 'technician')
      get url, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'crea con domicilio, guarda quién la creó y avisa de duplicados en español' do
    post url, params: { organization: { legal_name: 'Aceros del Norte SA', trade_name: 'Aceros del Norte', key: 'c-01',
                                        home_address_attributes: { street: 'Av. Juárez', exterior_number: '10' } } },
              headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    created = response.parsed_body['organization']
    expect(created).to include('organization_type' => 'prospect', 'key' => 'C-01', 'status' => 'active')
    expect(created['home_address']).to include('street' => 'Av. Juárez', 'consignee_name' => 'Aceros del Norte SA')
    expect(created['created_by']['id']).to eq(admin.id)

    post url, params: { organization: { legal_name: 'ACEROS DEL NORTE SA', trade_name: 'Otro' } },
              headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to eq('Razón social ya está dado de alta en otro cliente o prospecto')
  end

  it 'edita el domicilio sin duplicarlo y convierte el prospecto en cliente' do
    org = organization(home_address_attributes: { street: 'Av. Juárez' })
    patch "#{url}/#{org.id}", params: { organization: { phone: '871 123 4567', home_address_attributes: { street: 'Av. Morelos' } } },
                              headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['organization']['home_address']['street']).to eq('Av. Morelos')
    expect(org.addresses.count).to eq(1)

    post "#{url}/#{org.id}/convert", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['organization']['organization_type']).to eq('customer')
    post "#{url}/#{org.id}/convert", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no deja ver ni tocar organizaciones de otra cuenta' do
    foreign = create(:account).crm_organizations.create!(legal_name: 'Ajena', trade_name: 'Ajena')
    get "#{url}/#{foreign.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  describe 'consignatarios' do
    let(:org) { organization(home_address_attributes: { street: 'Av. Juárez', for_billing: true }) }
    let(:consignees_url) { "#{url}/#{org.id}/consignees" }

    it 'alta, cambio y baja; no incluyen el domicilio y solo uno factura' do
      post consignees_url, params: { consignee: { consignee_name: 'Bodega Sur', street: 'Calle 5', for_billing: true } },
                           headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
      id = response.parsed_body['consignee']['id']
      expect(org.reload.home_address).not_to be_for_billing

      get consignees_url, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['consignees'].pluck('consignee_name')).to eq(['Bodega Sur'])

      patch "#{consignees_url}/#{id}", params: { consignee: { phone2: '555' } }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['consignee']['phone2']).to eq('555')

      delete "#{consignees_url}/#{id}", headers: admin.create_new_auth_token, as: :json
      expect(org.addresses.count).to eq(1)
    end

    it 'el domicilio no se puede tocar por consignatarios' do
      delete "#{consignees_url}/#{org.home_address.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
