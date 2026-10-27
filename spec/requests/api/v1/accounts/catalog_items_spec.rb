# frozen_string_literal: true

require 'rails_helper'

# Plan-Catalogo-Cotizaciones C1 — Ventas › Catálogo.
RSpec.describe 'Catalog Items API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/catalog_items" }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def item(attrs = {})
    account.catalog_items.create!({ name: 'Mantenimiento A/C', kind: :service, price: 1200, cost: 400 }.merge(attrs))
  end

  it 'busca por nombre o clave y oculta los inactivos' do
    item(sku: 'MANT-01')
    item(name: 'Capacitor 35µF', kind: :part, sku: 'CAP-35', price: 180)
    item(name: 'Viejo', active: false)
    get url, params: { q: 'cap' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['catalog_items'].pluck('sku')).to eq(['CAP-35'])

    get url, params: { active: 'all' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['meta']['count']).to eq(3)
  end

  it 'el Técnico lo consulta (sin costo) pero no lo edita' do
    item
    give_role(agent, 'technician')
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['catalog_items'].first['cost']).to be_nil
    expect(body['meta']['can_edit']).to be(false)

    post url, params: { catalog_item: { name: 'Nuevo' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'el Supervisor crea y edita; la moneda por defecto es la de la cuenta' do
    post url, params: { catalog_item: { name: 'Instalación', kind: 'service', price: 2500, cost: 900 } },
              headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    created = response.parsed_body['catalog_item']
    expect(created['currency']).to eq('MXN')
    expect(created['cost']).to eq(900.0)

    patch "#{url}/#{created['id']}", params: { catalog_item: { active: false } }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['catalog_item']['active']).to be(false)
  end

  it 'no repite la clave' do
    item(sku: 'X1')
    post url, params: { catalog_item: { name: 'Otro', sku: 'X1' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'importa un CSV (crea y actualiza por clave) y exporta' do
    item(sku: 'MANT-01', price: 1000)
    csv = "clave,nombre,tipo,categoria,unidad,precio,moneda,costo,descripcion,activo\n" \
          "MANT-01,Mantenimiento A/C,servicio,Aires,servicio,1300,MXN,450,,si\n" \
          "CAP-35,Capacitor 35µF,refacción,Aires,pieza,180,MXN,60,,si\n" \
          ",,producto,,,,,,,si\n"
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv', original_filename: 'catalogo.csv')
    post "#{url}/import", params: { file: file }, headers: admin.create_new_auth_token
    body = response.parsed_body
    expect(body['created']).to eq(1)
    expect(body['updated']).to eq(1)
    expect(body['errors'].first['line']).to eq(4)
    expect(account.catalog_items.find_by(sku: 'MANT-01').price.to_f).to eq(1300.0)
    expect(account.catalog_items.find_by(sku: 'CAP-35').kind).to eq('part')

    get "#{url}/export", headers: admin.create_new_auth_token
    expect(response.body.lines.first.strip).to eq('clave,nombre,tipo,categoria,unidad,precio,moneda,costo,descripcion,activo')
    expect(response.body).to include('CAP-35')
  end

  it 'Consulta (sin Ventas ni Servicio) no entra' do
    give_role(agent, 'viewer')
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
