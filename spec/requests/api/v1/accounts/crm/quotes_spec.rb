# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q1 — API de cotizaciones y de series de folio.
RSpec.describe 'CrmZeus Quotes API' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/quotes" }
  let(:iva) { account.crm_taxes.find_by!(name: 'IVA 16%') }
  let(:seller) { account.crm_sellers.create!(name: 'Laura', user: agent) }
  let(:credit) { account.crm_payment_terms.create!(name: '30 días', installments_attributes: [{ days: 30, percent: 100 }]) }
  let(:organization) do
    account.crm_organizations.create!(legal_name: 'Aceros del Norte SA', trade_name: 'Aceros', organization_type: :customer,
                                      seller: seller, payment_term: credit, cfdi_use: 'G03')
  end
  let(:screws) { account.crm_articles.create!(name: 'Tornillo 1/2', key: 'TOR-12', catalog_status: :catalogued, taxes: [iva]) }
  let(:helmet) { account.crm_articles.create!(name: 'Casco', key: 'CAS-1', taxes: [iva]) }
  let(:gloves) { account.crm_articles.create!(name: 'Guantes', key: 'GUA-1') }
  let(:safety_kit) do
    account.crm_articles.create!(name: 'Kit de seguridad', key: 'KIT-1', is_kit: true, is_stockable: false, taxes: [iva],
                                 components_attributes: [{ component_id: helmet.id, quantity: 1, position: 1 },
                                                         { component_id: gloves.id, quantity: 2, position: 2 }])
  end

  before do
    Crm::DefaultCatalogs.ensure!(account)
    account.crm_quote_series.create!(user: agent, series: 'LAU', last_number: 124)
    account.crm_quote_series.create!(user: other_agent, series: 'PED')
  end

  def payload(attrs = {})
    { organization_id: organization.id, valid_until: 15.days.from_now.to_date, delivery_date: 7.days.from_now.to_date,
      items: [{ article_id: screws.id, quantity: 10, unit_price: 100, discount_percent: 14.5 },
              { description: 'Rondana', quantity: 3, unit_price: 49.99, tax_ids: [iva.id] }] }.merge(attrs)
  end

  def create_quote(user = agent, attrs = {})
    post url, params: { quote: payload(attrs) }, headers: user.create_new_auth_token, as: :json
    response.parsed_body['quote']
  end

  it 'el borrador trae los defaults del cliente y la serie del agente' do
    get "#{url}/new", params: { organization_id: organization.id }, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['quote']).to include('seller_id' => seller.id, 'payment_term_id' => credit.id, 'cfdi_use' => 'G03',
                                     'sat_payment_method' => 'PPD', 'exchange_rate' => 1.0)
    expect(body['series']).to eq('series' => 'LAU', 'next_folio' => 'LAU000125')
  end

  it 'calcula sin guardar, ignorando los totales que manda el navegador' do
    post "#{url}/calculate", params: { quote: payload(extra_discount_value: 2, total: 1) },
                             headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body['quote']
    expect(body).to include('net_amount' => 984.87, 'tax_total' => 157.58, 'total' => 1142.45)
    expect(body['items'].first).to include('net_amount' => 855.0, 'tax_ids' => [iva.id])
    expect(body['tax_summary'].sole).to include('name' => 'IVA 16%', 'amount' => 157.58)
    expect(account.crm_quotes.count).to eq(0)
  end

  it 'da de alta con folio del agente e impuestos del artículo cuando no se mandan' do
    created = create_quote(agent, extra_discount_value: 2)

    expect(response).to have_http_status(:created)
    expect(created).to include('folio' => 'LAU000125', 'status' => 'pending', 'total' => 1142.45, 'can_edit' => true,
                               'transitions' => %w[won lost cancelled])
    expect(created['items'].map { |i| [i['key'], i['description'], i['tax_ids']] })
      .to eq([['TOR-12', 'Tornillo 1/2', [iva.id]], [nil, 'Rondana', [iva.id]]])
  end

  it 'avisa lo que falta, en español' do
    post url, params: { quote: { organization_id: organization.id, items: [] } }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['attributes']).to include('valid_until', 'delivery_date', 'items')
  end

  it 'edita: cambia una partida, quita otra y agrega un kit con componentes; recalcula' do
    created = create_quote
    first = created['items'].first
    items = [{ id: first['id'], quantity: 1, unit_price: 100, discount_percent: 0, tax_ids: [iva.id] },
             { article_id: safety_kit.id, role: 'kit', quantity: 2, unit_price: 500, tax_ids: [iva.id],
               components: [{ description: 'Casco', quantity: 2 }, { description: 'Guantes', quantity: 4 }] }]
    patch "#{url}/#{created['id']}", params: { quote: { items: items } }, headers: agent.create_new_auth_token, as: :json

    updated = response.parsed_body['quote']
    expect(updated['items'].map { |i| [i['id'] == first['id'], i['description'], i['role']] })
      .to eq([[true, 'Tornillo 1/2', 'normal'], [false, 'Kit de seguridad', 'kit']])
    expect(updated['items'].last['components'].pluck('description', 'net_amount')).to eq([['Casco', 0.0], ['Guantes', 0.0]])
    expect(updated).to include('net_amount' => 1100.0, 'total' => 1276.0)

    kit = updated['items'].last
    patch "#{url}/#{created['id']}", params: { quote: { items: [kit.slice('id', 'description').merge(role: 'normal')] } },
                                     headers: agent.create_new_auth_token, as: :json
    expect(CrmQuoteItem.where(quote_id: created['id']).pluck(:description)).to eq(['Kit de seguridad'])
  end

  describe 'kits (Q3)' do
    def kit_row(attrs = {})
      { article_id: safety_kit.id, role: 'kit', quantity: 3, unit_price: 500 }.merge(attrs)
    end

    it 'un kit sin `components` toma los del catálogo: unidades por kit × cantidad, sin importe ni impuestos' do
      created = create_quote(agent, items: [kit_row])

      kit = created['items'].sole
      expect(kit).to include('role' => 'kit', 'key' => 'KIT-1', 'net_amount' => 1500.0, 'tax_ids' => [iva.id])
      expect(kit['components'].map { |c| c.values_at('key', 'description', 'quantity', 'net_amount', 'tax_ids') })
        .to eq([['CAS-1', 'Casco', 3.0, 0.0, []], ['GUA-1', 'Guantes', 6.0, 0.0, []]])
      expect(created).to include('net_amount' => 1500.0, 'tax_total' => 240.0)
    end

    it 'respeta los componentes que manda el navegador (unidades cambiadas o reemplazados)' do
      components = [{ article_id: gloves.id, quantity: 9, tax_ids: [] }]
      created = create_quote(agent, items: [kit_row(components: components)])

      expect(created['items'].sole['components'].pluck('description', 'quantity')).to eq([['Guantes', 9.0]])
    end

    it 'sin artículo no es kit' do
      created = create_quote(agent, items: [{ description: 'Paquete', role: 'kit', quantity: 1, unit_price: 10,
                                              components: [{ description: 'Algo', quantity: 1 }] }])

      expect(created['items'].sole).to include('role' => 'normal')
      expect(CrmQuoteItem.where(quote_id: created['id']).count).to eq(1)
    end

    it 'al editar un kit sin mandar `components` se quedan los que tenía' do
      created = create_quote(agent, items: [kit_row(components: [{ article_id: gloves.id, quantity: 9 }])])
      kit = created['items'].sole
      patch "#{url}/#{created['id']}", params: { quote: { items: [kit_row(id: kit['id'], quantity: 1)] } },
                                       headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['quote']['items'].sole['components'].pluck('description', 'quantity'))
        .to eq([['Guantes', 9.0]])
    end
  end

  it 'una partida de otra cotización es 404' do
    other = create_quote
    mine = create_quote
    patch "#{url}/#{mine['id']}", params: { quote: { items: [{ id: other['items'].first['id'], quantity: 1 }] } },
                                  headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'todos ven; solo el creador o un administrador edita y cambia el estatus' do
    created = create_quote

    get url, headers: other_agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quotes'].sole).to include('folio' => 'LAU000125', 'can_edit' => false)

    patch "#{url}/#{created['id']}", params: { quote: { footer_notes: 'x' } }, headers: other_agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
    post "#{url}/#{created['id']}/status", params: { status: 'won' }, headers: other_agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)

    post "#{url}/#{created['id']}/status", params: { status: 'won' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['quote']).to include('status' => 'won', 'transitions' => %w[lost cancelled])
  end

  it 'el estatus sigue las transiciones; ya no Pendiente no se edita' do
    created = create_quote
    post "#{url}/#{created['id']}/status", params: { status: 'cancelled' }, headers: agent.create_new_auth_token, as: :json
    post "#{url}/#{created['id']}/status", params: { status: 'won' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('Cancelada a Ganada')

    patch "#{url}/#{created['id']}", params: { quote: { footer_notes: 'x' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('Solo se puede editar una cotización Pendiente')
  end

  it 'filtra como CRMZeus (Pendientes predeterminado), por organización y por texto' do
    won = create_quote
    create_quote(other_agent)
    post "#{url}/#{won['id']}/status", params: { status: 'won' }, headers: agent.create_new_auth_token, as: :json

    fetch = lambda do |params|
      get url, params: params, headers: agent.create_new_auth_token, as: :json
      response.parsed_body['quotes'].pluck('folio')
    end
    expect(fetch.call({})).to eq(['PED000001'])
    expect(fetch.call(view: 'won_this_month')).to eq(['LAU000125'])
    expect(fetch.call(view: 'all', q: 'lau')).to eq(['LAU000125'])
    expect(fetch.call(view: 'all', organization_id: organization.id, created_by_id: other_agent.id)).to eq(['PED000001'])
  end

  it 'duplica sin guardar: misma partida, fecha de hoy y los mismos días de vigencia' do
    created = create_quote
    post "#{url}/#{created['id']}/duplicate", headers: other_agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['quote']).to include('organization_id' => organization.id, 'quote_date' => Time.zone.today.to_s,
                                     'valid_until' => 15.days.from_now.to_date.to_s, 'total' => created['total'])
    expect(body['quote']['items'].pluck('description', 'id')).to eq([['Tornillo 1/2', nil], ['Rondana', nil]])
    expect(body['series']['series']).to eq('PED')
    expect(account.crm_quotes.count).to eq(1)
  end

  it 'sin Ventas con escritura (Técnico) no da de alta' do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    account.account_users.find_by(user: agent).update!(access_role: role)
    create_quote

    expect(response).to have_http_status(:forbidden)
  end

  describe 'series de folio' do
    let(:series_url) { "/api/v1/accounts/#{account.id}/crm/quote_series" }

    it 'el Administrador las da de alta; serie repetida no; el agente no' do
      third = create(:user, account: account, role: :agent)
      post series_url, params: { quote_series: { user_id: third.id, series: 'ped' } }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['message']).to include('ya la usa otro agente')

      post series_url, params: { quote_series: { user_id: third.id, series: 'mar' } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      post series_url, params: { quote_series: { user_id: third.id, series: 'mar' } }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['item']).to include('series' => 'MAR', 'next_folio' => 'MAR000001')
      get series_url, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['items'].pluck('series')).to eq(%w[LAU MAR PED])
    end
  end
end
