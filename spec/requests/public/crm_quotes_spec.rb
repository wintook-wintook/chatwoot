# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q4.1 — la cotización que ve el cliente por su enlace (/cotizacion-crm/:token).
RSpec.describe 'CrmZeus public quote page' do
  let(:account) { create(:account, locale: 'es', name: 'Aceros Laguna') }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:iva) { account.crm_taxes.find_by!(name: 'IVA 16%') }
  let(:seller) { account.crm_sellers.create!(name: 'Laura', user: agent) }
  let(:credit) { account.crm_payment_terms.create!(name: '30 días', installments_attributes: [{ days: 30, percent: 100 }]) }
  let(:organization) do
    account.crm_organizations.create!(legal_name: 'Ferretería del Norte SA', trade_name: 'Ferre Norte', tax_id: 'FNO010101AB1',
                                      organization_type: :customer, seller: seller, payment_term: credit, cfdi_use: 'G03')
  end
  let(:screws) { account.crm_articles.create!(name: 'Tornillo 1/2', key: 'TOR-12', catalog_status: :catalogued, taxes: [iva]) }
  let(:helmet) { account.crm_articles.create!(name: 'Casco', key: 'CAS-1') }
  let(:safety_kit) do
    account.crm_articles.create!(name: 'Kit de seguridad', key: 'KIT-1', is_kit: true, is_stockable: false, taxes: [iva],
                                 components_attributes: [{ component_id: helmet.id, quantity: 2, position: 1 }])
  end

  before do
    Crm::DefaultCatalogs.ensure!(account)
    account.crm_quote_series.create!(user: agent, series: 'LAU', last_number: 124)
  end

  def quote_params
    items = [{ article_id: screws.id, quantity: 10, unit_price: 100, notes: 'Acero inoxidable' },
             { article_id: safety_kit.id, role: 'kit', quantity: 1, unit_price: 500 }]
    { organization_id: organization.id, valid_until: 15.days.from_now.to_date, delivery_date: 7.days.from_now.to_date,
      footer_notes: 'Precios sujetos a cambio', items: items }
  end

  def create_quote
    post "/api/v1/accounts/#{account.id}/crm/quotes", params: { quote: quote_params }, headers: agent.create_new_auth_token, as: :json
    raise response.body unless response.successful?

    account.crm_quotes.find(response.parsed_body['quote']['id'])
  end

  it 'enseña la cotización sin usuario: empresa, cliente, partidas, impuestos y cantidad con letra' do
    quote = create_quote
    get "/cotizacion-crm/#{quote.public_token}"

    expect(response).to have_http_status(:ok)
    html = response.body
    expect(html).to include('Aceros Laguna', 'LAU000125', 'Ferretería del Norte SA', 'RFC: FNO010101AB1', 'Laura', '30 días')
    expect(html).to include('TOR-12', 'Tornillo 1/2', 'Acero inoxidable', 'Kit de seguridad', 'IVA 16%')
    expect(html).to include('Precios sujetos a cambio', '$1,740.00')
    expect(html).to include(Crm::AmountInWords.new(quote.total, 'PESOS/M.N.').to_s)
    expect(html).not_to include('Casco')
    expect(html).not_to include('Pendiente')
  end

  it 'con el parámetro prendido enseña los componentes del kit, sin precio' do
    CrmSetting.for_account(account).update!(show_kit_components: true)
    quote = create_quote
    get "/cotizacion-crm/#{quote.public_token}"

    expect(response.body).to include('· Casco')
  end

  it 'una cotización cancelada se sigue viendo, con su estatus' do
    quote = create_quote
    quote.change_status!('cancelled', agent)
    get "/cotizacion-crm/#{quote.public_token}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Cancelada')
  end

  it 'un token que no existe es 404' do
    get '/cotizacion-crm/no-existe'

    expect(response).to have_http_status(:not_found)
  end
end
