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
                                 components_attributes: [{ component_id: helmet.id, quantity: 1, position: 1, replaceable: true },
                                                         { component_id: gloves.id, quantity: 2, position: 2,
                                                           units_editable: true }])
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

  it 'trae la cantidad en letra del total al guardar y en el cálculo (Q4.0, como master2)' do
    created = create_quote
    expect(created).to include('total' => 1165.77, 'amount_in_words' => 'Un mil ciento sesenta y cinco PESOS 77/100 M.N.')

    post "#{url}/calculate", params: { quote: payload(items: [{ description: 'Servicio', quantity: 1, unit_price: 100 }]) },
                             headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quote']['amount_in_words']).to eq('Cien PESOS 00/100 M.N.')
  end

  it 'el borrador trae los defaults del cliente y la serie del agente' do
    get "#{url}/new", params: { organization_id: organization.id }, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['quote']).to include('seller_id' => seller.id, 'payment_term_id' => credit.id, 'cfdi_use' => 'G03',
                                     'sat_payment_method' => 'PPD', 'exchange_rate' => 1.0)
    expect(body['series']).to eq('series' => 'LAU', 'next_folio' => 'LAU000125')
    expect(body['quote']['organization']).to include('seller_id' => seller.id, 'respect_seller' => false,
                                                     'charge_taxes' => true, 'withholds_taxes' => false)
  end

  describe 'valores por omisión del alta (Q3.1)' do
    def contact(name)
      create(:contact, account: account, name: name).tap { |row| organization.contact_links.create!(contact: row) }
    end

    def draft(params = { organization_id: organization.id })
      get "#{url}/new", params: params, headers: agent.create_new_auth_token, as: :json
      response.parsed_body['quote']
    end

    it 'vigencia y entrega hoy, aun sin organización' do
      expect(draft({})).to include('valid_until' => Time.zone.today.iso8601, 'delivery_date' => Time.zone.today.iso8601,
                                   'contact_id' => nil, 'shipping_address_id' => nil)
    end

    it 'con un solo contacto y un solo consignatario, esos' do
      ana = contact('Ana López')
      bodega = organization.consignees.create!(consignee_name: 'Bodega', street: 'Calle 5')

      expect(draft).to include('contact_id' => ana.id, 'shipping_address_id' => bodega.id)
    end

    it 'con varios, ninguno; pero el contacto de la última cotización si sigue ligado' do
      ana = contact('Ana López')
      beto = contact('Beto Ruiz')
      2.times { |n| organization.consignees.create!(consignee_name: "Bodega #{n}", street: 'Calle 5') }
      expect(draft).to include('contact_id' => nil, 'shipping_address_id' => nil)

      create_quote(agent, contact_id: beto.id, quote_date: 3.days.ago.to_date)
      create_quote(agent, contact_id: ana.id)
      expect(draft['contact_id']).to eq(ana.id)

      organization.contact_links.find_by!(contact: ana).destroy!
      expect(draft['contact_id']).to eq(beto.id)
    end

    it 'un prospecto no lleva consignatario' do
      organization.update!(organization_type: :prospect)
      organization.consignees.create!(consignee_name: 'Bodega', street: 'Calle 5')

      expect(draft['shipping_address_id']).to be_nil
    end

    it 'al guardar no se ponen: el agente los puede dejar vacíos' do
      contact('Ana López')

      expect(create_quote(agent, contact_id: nil)).to include('contact_id' => nil)
    end
  end

  it 'calcula sin guardar, ignorando los totales que manda el navegador' do
    post "#{url}/calculate", params: { quote: payload(extra_discount_value: 2, total: 1) },
                             headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body['quote']
    expect(body).to include('net_amount' => 984.87, 'tax_total' => 157.58, 'total' => 1142.45)
    expect(body['items'].first).to include('net_amount' => 855.0, 'tax_ids' => [iva.id])
    expect(body['tax_summary'].sole).to include('name' => 'IVA 16%', 'amount' => 157.58, 'base_amount' => 1004.97,
                                                'gross_base_amount' => 1149.97)
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

  it 'de los impuestos del artículo toma solo los que aplican al cliente' do
    ret_isr = account.crm_taxes.create!(name: 'Ret. ISR 10%', tax_type: :isr_withholding, percent: 10)
    service = account.crm_articles.create!(name: 'Servicio', key: 'SRV-1', taxes: [iva, ret_isr])
    item = { article_id: service.id, quantity: 1, unit_price: 100 }

    expect(create_quote(agent, items: [item])['items'].sole['tax_ids']).to eq([iva.id])

    organization.update!(charge_taxes: false, withholds_taxes: true)
    expect(create_quote(agent, items: [item])['items'].sole['tax_ids']).to eq([ret_isr.id])
  end

  it 'los impuestos de una partida con artículo no se eligen; la libre pasa por el filtro del cliente' do
    ret_isr = account.crm_taxes.create!(name: 'Ret. ISR 10%', tax_type: :isr_withholding, percent: 10)
    items = [{ article_id: screws.id, quantity: 1, unit_price: 100, tax_ids: [ret_isr.id] },
             { description: 'Flete', quantity: 1, unit_price: 50, tax_ids: [iva.id, ret_isr.id] }]

    expect(create_quote(agent, items: items)['items'].pluck('tax_ids')).to eq([[iva.id], [iva.id]])
  end

  it 'al editar conserva los impuestos guardados aunque cambien los del artículo (IMPUESTOS_DCDOCTOS_PDV_DET)' do
    created = create_quote
    ret_isr = account.crm_taxes.create!(name: 'Ret. ISR 10%', tax_type: :isr_withholding, percent: 10)
    organization.update!(withholds_taxes: true)
    screws.update!(taxes: [iva, ret_isr])
    rows = created['items'].map { |i| i.slice('id', 'article_id', 'description', 'quantity', 'unit_price').merge('tax_ids' => []) }

    post "#{url}/calculate", params: { quote_id: created['id'], quote: payload(items: rows) },
                             headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quote']['items'].first['tax_ids']).to eq([iva.id])

    patch "#{url}/#{created['id']}", params: { quote: { items: rows } }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quote']['items'].first['tax_ids']).to eq([iva.id])

    rows.first['article_id'] = gloves.id # sin impuestos: al cambiar de artículo se toman los del nuevo
    patch "#{url}/#{created['id']}", params: { quote: { items: rows } }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quote']['items'].first['tax_ids']).to eq([])
  end

  it 'la vista previa de una cotización guardada recalcula si cambia la organización' do
    created = create_quote
    exempt = account.crm_organizations.create!(legal_name: 'Exenta SA', trade_name: 'Exenta', organization_type: :customer,
                                               seller: seller, payment_term: credit, cfdi_use: 'G03', charge_taxes: false)
    rows = created['items'].map { |i| i.slice('id', 'article_id', 'description', 'quantity', 'unit_price', 'tax_ids') }

    post "#{url}/calculate", params: { quote_id: created['id'], quote: payload(organization_id: exempt.id, items: rows) },
                             headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['quote']['items'].pluck('tax_ids')).to eq([[], []])
  end

  it 'al cambiar de organización recalcula los impuestos de las partidas (resetPrices de CRMZeus)' do
    created = create_quote
    other = account.crm_organizations.create!(legal_name: 'Exenta SA', trade_name: 'Exenta', organization_type: :customer,
                                              seller: seller, payment_term: credit, cfdi_use: 'G03', charge_taxes: false)
    rows = created['items'].map { |i| i.slice('id', 'article_id', 'description', 'quantity', 'unit_price', 'tax_ids') }

    patch "#{url}/#{created['id']}", params: { quote: { organization_id: other.id, items: rows } },
                                     headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body['quote']
    expect(body['items'].pluck('tax_ids')).to eq([[], []])
    expect(body['tax_total']).to eq(0)
  end

  it 'avisa lo que falta, en español' do
    post url, params: { quote: { organization_id: organization.id, items: [] } }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['attributes']).to include('valid_until', 'items')
    expect(response.parsed_body['attributes']).not_to include('delivery_date')
  end

  it 'edita: cambia una partida, quita otra y agrega un kit con componentes; recalcula' do
    created = create_quote
    first = created['items'].first
    items = [{ id: first['id'], quantity: 1, unit_price: 100, discount_percent: 0, tax_ids: [iva.id] },
             { article_id: safety_kit.id, role: 'kit', quantity: 2, unit_price: 500, tax_ids: [iva.id],
               components: [{ article_id: helmet.id, quantity: 2 }, { article_id: gloves.id, quantity: 4 }] }]
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
        .to eq([['Guantes', 3.0]])
    end

    describe 'reglas del kit del catálogo' do
      before { safety_kit.components.find_by!(component: gloves).update!(replaceable: false, units_editable: false) }

      def rejected(components)
        post url, params: { quote: payload(items: [kit_row(components: components)]) },
                  headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        response.parsed_body['message']
      end

      it 'no quita ni cambia un componente no reemplazable, aunque permita cambiar unidades' do
        expect(rejected([{ article_id: helmet.id, quantity: 3 }])).to include('«Guantes» del kit «Kit de seguridad» no es reemplazable')
        safety_kit.components.find_by!(component: gloves).update!(units_editable: true)
        expect(rejected([{ article_id: helmet.id, quantity: 3 }])).to include('«Guantes» del kit «Kit de seguridad» no es reemplazable')
      end

      it 'no cambia las unidades de un componente que no lo permite' do
        expect(rejected([{ article_id: gloves.id, quantity: 7 }])).to include('«Guantes» del kit «Kit de seguridad» no permite cambiar unidades')
      end

      it 'un kit no almacenable no puede ser componente; uno almacenable sí; el kit no queda vacío' do
        other_kit = account.crm_articles.create!(name: 'Otro kit', is_kit: true, is_stockable: false)
        expect(rejected([{ article_id: gloves.id, quantity: 6 }, { article_id: other_kit.id, quantity: 1 }]))
          .to include('«Otro kit» es un kit no almacenable y no puede ser componente')
        stocked_kit = account.crm_articles.create!(name: 'Kit almacenable', is_kit: true, is_stockable: true)
        create_quote(agent, items: [kit_row(components: [{ article_id: gloves.id, quantity: 6 },
                                                         { article_id: stocked_kit.id, quantity: 1 }])])
        expect(response).to have_http_status(:created)
        expect(rejected([])).to include('debe tener al menos un componente')
      end

      it 'acepta quitar el reemplazable y agregar uno que no está en el catálogo' do
        screwdriver = account.crm_articles.create!(name: 'Desarmador')
        created = create_quote(agent, items: [kit_row(components: [{ article_id: gloves.id, quantity: 6 },
                                                                   { article_id: screwdriver.id, quantity: 5 }])])

        expect(response).to have_http_status(:created)
        expect(created['items'].sole['components'].pluck('description')).to eq(%w[Guantes Desarmador])
      end
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

  it 'duplica sin guardar: mismas partidas; fecha, vigencia y entrega de hoy' do
    created = create_quote
    post "#{url}/#{created['id']}/duplicate", headers: other_agent.create_new_auth_token, as: :json

    body = response.parsed_body
    today = Time.zone.today.to_s
    expect(body['quote']).to include('organization_id' => organization.id, 'quote_date' => today, 'valid_until' => today,
                                     'delivery_date' => today, 'total' => created['total'])
    expect(body['quote']['items'].pluck('description', 'id')).to eq([['Tornillo 1/2', nil], ['Rondana', nil]])
    expect(body['removed_items']).to eq([])
    expect(body['series']['series']).to eq('PED')
    expect(account.crm_quotes.count).to eq(1)
  end

  it 'duplica lo que hay en pantalla aunque no esté guardado (como master2)' do
    created = create_quote
    screen = payload(header_notes: 'Cambiado sin guardar', purchase_order: 'OC-77', purchase_order_date: '2026-11-20',
                     items: [created['items'].first.slice('id', 'article_id', 'quantity', 'unit_price'),
                             { article_id: safety_kit.id, role: 'kit', quantity: 1, unit_price: 500 }])
    safety_kit.update!(status: :inactive)
    post "#{url}/#{created['id']}/duplicate", params: { quote: screen }, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['quote']).to include('header_notes' => 'Cambiado sin guardar', 'valid_until' => Time.zone.today.to_s,
                                     'purchase_order' => 'OC-77', 'purchase_order_date' => '2026-11-20')
    expect(body['quote']['items'].pluck('description', 'id')).to eq([['Tornillo 1/2', nil]])
    expect(body['removed_items']).to eq(['Kit de seguridad'])
    expect(account.crm_quotes.find(created['id']).items.count).to eq(2)
  end

  it 'al duplicar quita las partidas de artículos de baja o suspendidos de ventas, con todo y componentes (Q3.1)' do
    created = create_quote(agent, items: [{ article_id: screws.id, quantity: 1, unit_price: 100 },
                                          { article_id: safety_kit.id, role: 'kit', quantity: 1, unit_price: 500 },
                                          { article_id: gloves.id, quantity: 1, unit_price: 10 }])
    duplicate = lambda do
      post "#{url}/#{created['id']}/duplicate", headers: agent.create_new_auth_token, as: :json
      response.parsed_body
    end

    safety_kit.update!(status: :sales_suspended)
    screws.update!(status: :purchases_suspended)
    body = duplicate.call
    expect(body['quote']['items'].pluck('description')).to eq(['Tornillo 1/2', 'Guantes'])
    expect(body['removed_items']).to eq(['Kit de seguridad'])

    gloves.update!(status: :inactive)
    screws.update!(status: :suspended)
    expect(duplicate.call).to include('removed_items' => ['Tornillo 1/2', 'Kit de seguridad', 'Guantes'])
    expect(response.parsed_body['quote']['items']).to eq([])
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
