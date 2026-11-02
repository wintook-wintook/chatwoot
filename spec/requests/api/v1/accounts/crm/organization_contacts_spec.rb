# frozen_string_literal: true

require 'rails_helper'

# CrmZeus C1 — API de contactos de Wintook ligados a una organización.
RSpec.describe 'CrmZeus Organization Contacts API' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:organization) { account.crm_organizations.create!(legal_name: 'Aceros del Norte SA', trade_name: 'Aceros') }
  let(:other_organization) { account.crm_organizations.create!(legal_name: 'Pinturas SA', trade_name: 'Pinturas') }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/organizations/#{organization.id}/contacts" }
  let!(:ana) { create(:contact, account: account, name: 'Ana López', email: 'ana@aceros.mx') }
  let!(:beto) { create(:contact, account: account, name: 'Beto Ruiz', phone_number: '+5218711234567') }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  it 'liga, lista y desliga sin borrar al contacto' do
    post url, params: { contact_id: ana.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['contact']).to include('id' => ana.id, 'name' => 'Ana López', 'email' => 'ana@aceros.mx')

    post url, params: { contact_id: beto.id }, headers: admin.create_new_auth_token, as: :json
    get url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contacts'].pluck('name')).to eq(['Ana López', 'Beto Ruiz'])

    delete "#{url}/#{ana.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(organization.contacts.reload).to contain_exactly(beto)
    expect(Contact.exists?(ana.id)).to be(true)
  end

  it 'rechaza un contacto que ya está en otra organización, nombrándola' do
    other_organization.contact_links.create!(contact: ana)
    post url, params: { contact_id: ana.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('ya pertenece a «Pinturas»')
  end

  it 'busca contactos de Wintook y dice si ya están en una organización' do
    other_organization.contact_links.create!(contact: ana)
    get "#{url}/search", params: { q: 'ana' }, headers: admin.create_new_auth_token, as: :json
    found = response.parsed_body['contacts']
    expect(found.pluck('id')).to eq([ana.id])
    expect(found.first['crm_organization']).to eq('id' => other_organization.id, 'trade_name' => 'Pinturas')

    get "#{url}/search", params: { q: '871123' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contacts'].first).to include('id' => beto.id, 'crm_organization' => nil)
  end

  it 'el Vendedor («solo lo suyo» en Clientes) ve todos los ligados pero solo busca y liga los suyos' do
    give_role(agent, 'seller')
    organization.contact_links.create!(contact: beto)
    ana.update!(owner: agent)

    get url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['contacts'].pluck('id')).to eq([beto.id])

    get "#{url}/search", params: { q: 'o' }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['contacts'].pluck('id')).to eq([ana.id])

    post url, params: { contact_id: create(:contact, account: account, email: 'x@y.mx').id },
              headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)

    post url, params: { contact_id: ana.id }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
  end

  it 'sin Ventas (Técnico) no entra' do
    give_role(agent, 'technician')
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'no liga contactos ni organizaciones de otra cuenta' do
    post url, params: { contact_id: create(:contact, email: 'otro@x.mx').id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)

    foreign = create(:account).crm_organizations.create!(legal_name: 'Ajena SA', trade_name: 'Ajena')
    get "/api/v1/accounts/#{account.id}/crm/organizations/#{foreign.id}/contacts", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
