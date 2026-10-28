# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O1 — API de prospectos y clientes.
RSpec.describe 'Organizations API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let!(:contact) { create(:contact, account: account, name: 'Ana', email: 'ana@acme.mx') }
  let(:base) { "/api/v1/accounts/#{account.id}/organizations" }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  it 'convierte un contacto en prospecto, lo marca cliente y cuenta por etapa' do
    post base, params: { contact_id: contact.id, organization: { name: 'Acme', kind: 'company' } },
               headers: admin.create_new_auth_token,
               as: :json
    expect(response).to have_http_status(:created)
    org = response.parsed_body['organization']
    expect(org).to include('name' => 'Acme', 'stage' => 'prospect', 'kind' => 'company', 'contacts_count' => 1)
    expect(contact.reload.organization_id).to eq(org['id'])

    post "#{base}/#{org['id']}/change_stage", params: { stage: 'customer' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['organization']).to include('stage' => 'customer')
    expect(response.parsed_body['organization']['events'].first['user']['id']).to eq(admin.id)

    get base, params: { stage: 'customer' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['organizations'].pluck('id')).to eq([org['id']])
    expect(response.parsed_body['meta']['counts']).to include('prospect' => 0, 'customer' => 1, 'all' => 1)
  end

  it 'liga y quita contactos' do
    org = account.organizations.create!(name: 'Acme')
    post "#{base}/#{org.id}/add_contact", params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['organization']['contacts'].pluck('id')).to eq([contact.id])
    post "#{base}/#{org.id}/remove_contact", params: { contact_id: contact.id }, headers: admin.create_new_auth_token,
                                             as: :json
    expect(contact.reload.organization_id).to be_nil
  end

  it 'lo creado para un contacto toma su organización y sale en el resumen' do
    org = account.organizations.create!(name: 'Acme')
    contact.update!(organization: org)
    type = account.contract_types.create!(name: 'Iguala')
    contract = account.contracts.create!(contact: contact, contract_type: type, title: 'Iguala', price: 100,
                                         starts_on: Date.current)
    asset = account.customer_assets.create!(contact: contact, name: 'Panel')
    expect([contract.organization_id, asset.organization_id]).to eq([org.id, org.id])

    contact.update!(organization: nil)
    expect(contract.reload.organization_id).to eq(org.id)

    get "#{base}/#{org.id}/summary", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contracts'].pluck('id')).to eq([contract.id])
    expect(response.parsed_body['assets'].pluck('id')).to eq([asset.id])
  end

  it 'importa organizaciones de CSV: crea, actualiza por RFC, liga contactos y reporta errores' do
    csv = "nombre,tipo,etapa,rfc,contactos\nAcme,empresa,cliente,ACM010101AAA,ana@acme.mx\n" \
          "Acme Nueva,empresa,,ACM010101AAA,\nPerez,publico_en_general,,,nadie@x.mx\n"
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv', original_filename: 'organizaciones.csv')
    post "#{base}/import", params: { file: file }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('created' => 1, 'updated' => 1)
    expect(response.parsed_body['errors'].first).to include('line' => 4)
    org = account.organizations.find_by(tax_id: 'ACM010101AAA')
    expect(org).to have_attributes(name: 'Acme Nueva', stage: 'customer')
    expect(contact.reload.organization).to eq(org)
  end

  it 'métricas: totales, nuevos del periodo, conversión y días a cliente' do
    travel_to Time.zone.parse('2026-10-15 12:00') do
      account.organizations.create!(name: 'A', became_prospect_at: 10.days.ago)
      account.organizations.create!(name: 'B', stage: :customer, kind: :general_public,
                                    became_prospect_at: 20.days.ago, became_customer_at: 10.days.ago)
      account.organizations.create!(name: 'Vieja', stage: :customer, became_prospect_at: 2.years.ago,
                                    became_customer_at: 2.years.ago)
      get "#{base}/metrics", params: { months: 3 }, headers: admin.create_new_auth_token, as: :json
    end
    body = response.parsed_body
    expect(body['totals']).to include('prospect' => 1, 'customer' => 2, 'company' => 2, 'general_public' => 1)
    expect(body).to include('new_prospects' => 2, 'new_customers' => 1, 'conversion_rate' => 50.0,
                            'avg_days_to_customer' => 10.0)
    expect(body['monthly'].last(2)).to eq([{ 'month' => '2026-09', 'prospects' => 1, 'customers' => 0 },
                                           { 'month' => '2026-10', 'prospects' => 1, 'customers' => 1 }])
  end

  it 'con «solo lo suyo» ve las que tiene a cargo o las de sus contactos; sin Clientes, nada' do
    give_role(agent, 'seller')
    suya = account.organizations.create!(name: 'Suya', owner: agent)
    account.organizations.create!(name: 'Ajena')
    get base, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['organizations'].pluck('name')).to eq(['Suya'])
    expect(suya).to be_persisted

    give_role(agent, 'viewer')
    get base, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
