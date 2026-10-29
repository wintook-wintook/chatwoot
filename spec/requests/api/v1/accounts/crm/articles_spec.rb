# frozen_string_literal: true

require 'rails_helper'

# CrmZeus A1 — API de artículos y de sus catálogos (líneas, unidades, impuestos, listas de precios).
RSpec.describe 'CrmZeus Articles API' do
  let(:account) { create(:account, locale: 'es') } # como las cuentas reales: los errores salen en español
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:base)    { "/api/v1/accounts/#{account.id}/crm" }
  let(:url)     { "#{base}/articles" }
  let(:list_price) { account.crm_lookups.price_list.find_by!(name: 'Precio de lista') }
  let(:peso) { account.crm_currencies.find_by!(iso_code: 'MXN') }
  let(:iva) { account.crm_taxes.find_by!(name: 'IVA 16%') }
  let(:pieza) { account.crm_units.find_by!(name: 'Pieza') }

  before { Crm::DefaultCatalogs.ensure!(account) }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def article(attrs = {})
    account.crm_articles.create!({ name: 'Casco de seguridad' }.merge(attrs))
  end

  it 'crea con precios por lista e impuestos; el Vendedor también puede (sin restricción por tipo)' do
    give_role(agent, 'seller')
    post url, params: { article: { catalog_status: 'catalogued', key: 'cas-01', name: 'Casco de seguridad', unit_id: pieza.id, is_kit: true,
                                   tax_ids: [iva.id],
                                   prices_attributes: [{ price_list_id: list_price.id, price: 350.5, currency_id: peso.id }] } },
              headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    created = response.parsed_body['article']
    expect(created).to include('catalog_status' => 'catalogued', 'key' => 'CAS-01', 'tax_ids' => [iva.id], 'is_kit' => true)
    expect(created['prices'].first).to include('price_list' => 'Precio de lista', 'price' => 350.5, 'currency' => 'MXN')
    expect(created['default_price']).to eq('price' => 350.5, 'price_list' => 'Precio de lista', 'currency' => 'MXN')
    expect(created['created_by']['id']).to eq(agent.id)
  end

  it 'avisa del nombre repetido sin acentos, en español' do
    article
    post url, params: { article: { name: 'CASCO DE SÉGURIDAD' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to eq('Nombre ya está dado de alta en otro artículo')
  end

  it 'rechaza un impuesto de otra cuenta' do
    other = create(:account)
    Crm::DefaultCatalogs.ensure!(other)
    post url, params: { article: { name: 'X', tax_ids: [other.crm_taxes.first.id] } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'lista con pestañas y búsqueda; sin Ventas (Técnico) no entra' do
    article(catalog_status: :catalogued, key: 'CAS-01')
    article(name: 'Cañón de agua')
    get url, params: { type: 'uncatalogued', q: 'canon' }, headers: admin.create_new_auth_token, as: :json
    body = response.parsed_body
    expect(body['articles'].pluck('name')).to eq(['Cañón de agua'])
    expect(body['meta']['counts']).to eq('catalogued' => 0, 'uncatalogued' => 1, 'all' => 1)

    give_role(agent, 'technician')
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'edita precios (cambia, quita, agrega) e impuestos, y cataloga' do
    record = article(prices_attributes: [{ price_list: list_price, price: 100 }], taxes: [iva])
    wholesale = account.crm_lookups.create!(kind: :price_list, name: 'Mayoreo')
    price = record.prices.first
    patch "#{url}/#{record.id}", params: { article: { tax_ids: [],
                                                      prices_attributes: [{ id: price.id, _destroy: true },
                                                                          { price_list_id: wholesale.id, price: 80 }] } },
                                 headers: admin.create_new_auth_token, as: :json
    updated = response.parsed_body['article']
    expect(updated['prices'].map { |p| [p['price_list'], p['price']] }).to eq([['Mayoreo', 80.0]])
    expect(updated['tax_ids']).to eq([])

    post "#{url}/#{record.id}/catalog", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['article']['catalog_status']).to eq('catalogued')
    post "#{url}/#{record.id}/catalog", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'sube y quita la imagen; rechaza un archivo que no es imagen' do
    record = article
    png = Rack::Test::UploadedFile.new(StringIO.new('fake-png'), 'image/png', original_filename: 'casco.png')
    post "#{url}/#{record.id}/image", params: { image: png }, headers: admin.create_new_auth_token
    expect(response.parsed_body['article']['image_url']).to include('casco.png')

    pdf = Rack::Test::UploadedFile.new(StringIO.new('fake-pdf'), 'application/pdf', original_filename: 'ficha.pdf')
    post "#{url}/#{record.id}/image", params: { image: pdf }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)

    delete "#{url}/#{record.id}/image", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['article']['image_url']).to be_nil
  end

  describe 'catálogos de artículos' do
    it 'el catálogo completo trae líneas, unidades, impuestos y listas de precios' do
      get "#{base}/catalogs", headers: agent.create_new_auth_token, as: :json
      body = response.parsed_body
      expect(body['units'].pluck('name')).to eq(%w[Pieza Servicio])
      expect(body['taxes'].pluck('name')).to eq(['IVA 0%', 'IVA 16%', 'Exento'])
      expect(body['lookups']['price_list'].pluck('name')).to eq(['Precio de lista'])
      expect(body['tax_types']).to include('vat', 'vat_exempt', 'isr_withholding')
    end

    it 'el Administrador da de alta líneas, unidades e impuestos; el agente no' do
      post "#{base}/units", params: { unit: { name: 'Kilogramo', sat_key: 'kgm' } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      post "#{base}/units", params: { unit: { name: 'Kilogramo', sat_key: 'kgm' } }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['item']).to include('sat_key' => 'KGM')

      group = account.crm_lookups.create!(kind: :line_group, name: 'Protección')
      post "#{base}/article_lines", params: { article_line: { name: 'Cascos', group_id: group.id } },
                                    headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['item']).to include('group_name' => 'Protección')

      post "#{base}/taxes", params: { tax: { name: 'Retención ISR 10%', tax_type: 'isr_withholding', percent: 10 } },
                            headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['item']).to include('tax_type' => 'isr_withholding', 'percent' => 10.0)
    end

    it 'no borra lo que usa un artículo: unidad, impuesto, línea, lista de precios ni grupo de líneas' do
      group = account.crm_lookups.create!(kind: :line_group, name: 'Protección')
      line = account.crm_article_lines.create!(name: 'Cascos', group: group)
      article(unit: pieza, line: line, taxes: [iva], prices_attributes: [{ price_list: list_price, price: 1 }])

      { "units/#{pieza.id}" => 'Lo usa 1 artículo', "taxes/#{iva.id}" => 'Lo usa 1 artículo',
        "article_lines/#{line.id}" => 'Lo usa 1 artículo', "lookups/#{list_price.id}" => 'Lo usa 1 precio de artículo',
        "lookups/#{group.id}" => 'Lo usa 1 línea' }.each do |path, message|
        delete "#{base}/#{path}", headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unprocessable_entity), path
        expect(response.parsed_body['message']).to start_with(message)
      end
    end
  end

  describe 'componentes del kit' do
    let(:helmet) { article(key: 'CAS-01', unit: pieza) }
    let(:gloves) { article(name: 'Guantes') }

    it 'los guarda anidados, los regresa con clave y unidad, y los quita con _destroy' do
      kit = article(name: 'Kit de seguridad', is_kit: true)
      patch "#{url}/#{kit.id}", params: { article: { components_attributes: [
        { component_id: helmet.id, quantity: 1, position: 0 }, { component_id: gloves.id, quantity: 2.5, position: 1, replaceable: true }
      ] } }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      rows = response.parsed_body['article']['components']
      expect(rows.first).to include('component_id' => helmet.id, 'key' => 'CAS-01', 'name' => 'Casco de seguridad', 'unit' => 'Pieza',
                                    'quantity' => 1.0, 'replaceable' => false)
      expect(rows.last).to include('name' => 'Guantes', 'quantity' => 2.5, 'replaceable' => true)

      patch "#{url}/#{kit.id}", params: { article: { components_attributes: [{ id: rows.first['id'], _destroy: true }] } },
                                headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['article']['components'].pluck('name')).to eq(['Guantes'])
    end

    it 'rechaza otro kit como componente, en español' do
      kit = article(name: 'Kit de seguridad', is_kit: true)
      other = article(name: 'Kit de lluvia', is_kit: true)
      patch "#{url}/#{kit.id}", params: { article: { components_attributes: [{ component_id: other.id, quantity: 1 }] } },
                                headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Componente no puede ser otro kit')
    end

    it 'no elimina un artículo que es componente de un kit' do
      article(name: 'Kit de seguridad', is_kit: true).components.create!(component: helmet)
      delete "#{url}/#{helmet.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('No se puede eliminar: es componente de «Kit de seguridad»')
    end
  end
end
