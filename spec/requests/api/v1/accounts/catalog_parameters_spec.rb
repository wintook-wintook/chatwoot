# frozen_string_literal: true

require 'rails_helper'

# Productos y servicios › Parámetros — categorías con subcategorías, impuestos y unidades de medida.
RSpec.describe 'Catalog Parameters API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/catalog_parameters" }
  let(:headers) { admin.create_new_auth_token }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  it 'la primera vez trae impuestos y unidades de fábrica y pasa a las listas lo que ya estaba escrito' do
    CaseSetting.for_account(account).update!(default_tax_percent: 16)
    old = account.catalog_items.create!(name: 'Balata', price: 100)
    old.update_columns(category: 'Refacciones > Frenos', unit: 'PZA') # rubocop:disable Rails/SkipsModelValidations

    get url, headers: headers, as: :json
    body = response.parsed_body
    expect(body['taxes'].find { |t| t['is_default'] }['name']).to eq('IVA 16 %')
    expect(body['units'].pluck('abbreviation')).to include('pza', 'hr', 'serv')
    expect(body['categories'].first).to include('name' => 'Refacciones')
    expect(body['categories'].first['children'].first).to include('name' => 'Frenos', 'items' => 1)
    expect(old.reload).to have_attributes(category: 'Refacciones › Frenos', unit: 'pza')
  end

  it 'agrega una subcategoría, la renombra (los productos se enteran) y no la borra si se usa' do
    get url, headers: headers, as: :json
    post "#{url}/categories", params: { record: { name: 'Servicios' } }, headers: headers, as: :json
    parent = account.catalog_categories.find_by(name: 'Servicios')
    post "#{url}/categories", params: { record: { name: 'Instalación', parent_id: parent.id } }, headers: headers, as: :json
    child = parent.children.first
    product = account.catalog_items.create!(name: 'Instalar minisplit', price: 1500, catalog_category_id: child.id)
    expect(product.category).to eq('Servicios › Instalación')

    patch "#{url}/categories/#{child.id}", params: { record: { name: 'Instalaciones' } }, headers: headers, as: :json
    expect(product.reload.category).to eq('Servicios › Instalaciones')

    delete "#{url}/categories/#{child.id}", headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    patch "#{url}/categories/#{child.id}", params: { record: { active: false } }, headers: headers, as: :json
    expect(child.reload.active).to be(false)
  end

  it 'solo hay un impuesto por omisión y es el que usan las partidas sin producto' do
    get url, headers: headers, as: :json
    eight = account.tax_rates.find_by(percent: 8)
    patch "#{url}/taxes/#{eight.id}", params: { record: { is_default: true } }, headers: headers, as: :json
    expect(account.tax_rates.where(is_default: true).pluck(:id)).to eq([eight.id])
    expect(CaseSetting.for_account(account).default_tax_percent).to eq(8)

    delete "#{url}/taxes/#{eight.id}", headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el producto cotiza con su impuesto y, si el precio lo incluye, lo separa' do
    get url, headers: headers, as: :json
    zero = account.tax_rates.find_by(name: 'IVA 0 %')
    sixteen = account.tax_rates.find_by(percent: 16)
    food = account.catalog_items.create!(name: 'Tortilla', price: 20, tax_rate: zero)
    gross = account.catalog_items.create!(name: 'Póliza', price: 116, tax_rate: sixteen, price_includes_tax: true)
    expect(food.quote_tax_percent).to eq(0)
    expect(gross.quote_unit_price).to eq(100)
    expect(gross.quote_tax_percent).to eq(16)
  end

  it 'al importar, la categoría, la unidad y el impuesto que no existen se crean o se buscan' do
    get url, headers: headers, as: :json
    csv = "nombre,categoria,unidad,precio,impuesto,precio_con_impuesto,clave_sat\nCable,Material › Eléctrico,rollo,500,8,si,26121600\n"
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv', original_filename: 'catalogo.csv')
    post "/api/v1/accounts/#{account.id}/catalog_items/import", params: { file: file }, headers: headers
    item = account.catalog_items.find_by(name: 'Cable')
    expect(item).to have_attributes(category: 'Material › Eléctrico', unit: 'rollo', price_includes_tax: true, sat_code: '26121600')
    expect(item.tax_rate.percent).to eq(8)
    expect(item.catalog_unit).to be_present
  end

  it 'quien solo consulta el catálogo ve las listas pero no las cambia' do
    give_role(agent, 'technician')
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['can_edit']).to be(false)
    post "#{url}/units", params: { record: { name: 'Rollo', abbreviation: 'rollo' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  describe 'retenciones' do
    let(:org_moral) { account.organizations.create!(name: 'Constructora SA', tax_id: 'CON010101AB1') }
    let(:org_fisica) { account.organizations.create!(name: 'Juan Pérez', tax_id: 'PEJJ800101AB1') }

    before do
      CaseSetting.for_account(account).update!(default_tax_percent: 16)
      get url, headers: headers, as: :json
    end

    def quote_for(organization, product)
      contact = create(:contact, account: account, organization: organization)
      quote = Quotes::Builder.new(account, admin).create!({ contact_id: contact.id })
      quote.items.create!(account: account, catalog_item: product, description: product.name, quantity: 1,
                          unit_price: product.quote_unit_price, tax_percent: product.quote_tax_percent,
                          withholdings: product.quote_withholdings)
      quote.recalculate!
      quote
    end

    it 'vienen de fábrica y el producto lleva las suyas; solo se restan si el cliente es persona moral' do
      ret_iva = account.tax_rates.withholding.find_by(name: 'Ret. IVA 10.67 %')
      ret_isr = account.tax_rates.withholding.find_by(name: 'Ret. ISR 10 %')
      expect(ret_iva.percent).to eq(BigDecimal('10.6667'))
      service = account.catalog_items.create!(name: 'Asesoría', price: 1000, withholding_rate_ids: [ret_iva.id, ret_isr.id])

      moral = quote_for(org_moral, service)
      expect(moral).to have_attributes(apply_withholdings: true, tax_total: 160, withholding_total: 206.67, total: 953.33)
      expect(moral.withholding_breakdown).to eq('Ret. IVA 10.67 %' => 106.67, 'Ret. ISR 10 %' => 100)

      fisica = quote_for(org_fisica, service)
      expect(fisica).to have_attributes(apply_withholdings: false, withholding_total: 0, total: 1160)
    end

    it 'una retención no puede ser el impuesto del producto ni el de por omisión, y no se borra si un producto la usa' do
      ret = account.tax_rates.withholding.first
      expect(account.catalog_items.new(name: 'X', price: 1, tax_rate: ret)).not_to be_valid
      expect(ret.update(is_default: true)).to be(false)
      account.catalog_items.create!(name: 'Flete', price: 500, withholding_rate_ids: [ret.id])
      delete "#{url}/taxes/#{ret.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
