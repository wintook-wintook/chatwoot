# frozen_string_literal: true

require 'rails_helper'

# Plan-Catalogo-Cotizaciones V1 — cotizaciones solas o ligadas, sus estados y la
# sincronización con la oportunidad.
RSpec.describe 'Quotes API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Jane Pérez') }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:url)     { "/api/v1/accounts/#{account.id}/quotes" }
  let(:items) do
    [{ description: 'Mantenimiento A/C', quantity: 2, unit_price: 1000, discount_percent: 10, tax_percent: 16 },
     { description: 'Capacitor', quantity: 1, unit_price: 200 }]
  end

  def create_quote(user = admin, extra = {})
    post url, params: { quote: { contact_id: contact.id }.merge(extra.except(:items, :create_opportunity)),
                        items: extra.fetch(:items, items), create_opportunity: extra[:create_opportunity] },
              headers: user.create_new_auth_token, as: :json
    response.parsed_body['quote']
  end

  def move(quote, to, extra = {})
    post "#{url}/#{quote['id']}/transition", params: { to: to }.merge(extra), headers: admin.create_new_auth_token, as: :json
    response.parsed_body
  end

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta }.merge(attrs))
  end

  it 'sola: folio, totales con descuento e impuesto, y su propio estado' do
    quote = create_quote
    expect(quote['folio']).to eq('COT-0001')
    expect(quote['subtotal']).to eq(2200.0)
    expect(quote['discount_total']).to eq(200.0)
    expect(quote['tax_total']).to eq(288.0)
    expect(quote['total']).to eq(2288.0)
    expect(quote['opportunity']).to be_nil

    expect(move(quote, 'sent')['quote']['status']).to eq('sent')
    expect(move(quote, 'lost', note: 'Precio')['quote']['status']).to eq('lost')
    expect(account.case_tickets.count).to eq(0)
  end

  it 'con una sola cotización la oportunidad es su espejo' do
    opp = opportunity
    quote = create_quote(admin, opportunity_id: opp.id)
    move(quote, 'sent')
    move(quote, 'postponed', postponed_until: 1.week.from_now.to_date)
    expect(opp.reload).to be_postponed
    move(quote, 'sent')
    expect(opp.reload).not_to be_postponed
    move(quote, 'won')
    expect(opp.reload.outcome).to eq('won')
    expect(opp.amount.to_f).to eq(2288.0)
  end

  it 'con varias: ganar una cancela las demás; si se pierden todas, pregunta' do
    opp = opportunity
    first = create_quote(admin, opportunity_id: opp.id)
    second = create_quote(admin, opportunity_id: opp.id)
    move(first, 'sent')
    move(second, 'sent')
    expect(move(first, 'lost')['prompt']).to be_nil
    expect(move(second, 'lost')['prompt']).to eq('all_closed')
    expect(opp.reload.outcome).to be_nil

    third = create_quote(admin, opportunity_id: opp.id)
    fourth = create_quote(admin, opportunity_id: opp.id)
    move(fourth, 'won')
    expect(Quote.find(third['id'])).to be_cancelled
    expect(Quote.find(third['id']).outcome_note).to include(fourth['folio'])
    expect(opp.reload.outcome).to eq('won')
  end

  it 'la oportunidad manda: ganada, perdida o pospuesta se refleja en sus cotizaciones' do
    opp = opportunity
    a = create_quote(admin, opportunity_id: opp.id)
    b = create_quote(admin, opportunity_id: opp.id)
    opp.postpone!(until_date: 1.week.from_now.to_date)
    expect(Quote.where(id: [a['id'], b['id']]).pluck(:status).uniq).to eq(['postponed'])
    opp.resume!
    expect(Quote.where(id: [a['id'], b['id']]).pluck(:status).uniq).to eq(['sent'])
    opp.close_with_outcome!(:won, accepted_quote_id: b['id'])
    expect(Quote.find(b['id'])).to be_won
    expect(Quote.find(a['id'])).to be_cancelled
  end

  it 'nueva versión: misma numeración, la anterior queda cancelada' do
    quote = create_quote
    post "#{url}/#{quote['id']}/new_version", headers: admin.create_new_auth_token, as: :json
    copy = response.parsed_body['quote']
    expect(copy['folio']).to eq('COT-0001 v2')
    expect(copy['items'].size).to eq(2)
    expect(Quote.find(quote['id'])).to be_cancelled
  end

  it 'si la empresa lo exige, crea la oportunidad sola' do
    venta
    CaseSetting.for_account(account).update!(quotes_require_opportunity: true)
    quote = create_quote
    expect(quote['opportunity']['title']).to eq(I18n.t('quotes.opportunity_title', folio: 'COT-0001'))
    expect(CaseTicket.find(quote['opportunity']['id']).amount.to_f).to eq(2288.0)
  end

  it 'aceptada desde una orden de trabajo: sus partidas pasan a la orden' do
    account.enable_features!('case_work_order')
    orden_type = CaseType.create!(account: account, name: 'Visita', color: '#0d9488', case_class: :work_order)
    order = CaseTicket.create!(account: account, title: 'Visita', contact: contact, case_type: orden_type)
    quote = create_quote(admin, origin_ticket_id: order.id)
    move(quote, 'won')
    expect(order.work_order_items.pluck(:description)).to eq(['Mantenimiento A/C', 'Capacitor'])
  end

  it 'roles: el Vendedor ve solo las suyas; el Técnico no ve importes de las ajenas' do
    create_quote(admin)
    seller = AccessRole.for_account(account).find { |r| r.key == 'seller' }
    account.account_users.find_by(user: agent).update!(access_role: seller)
    create_quote(agent)
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['quotes'].size).to eq(1)
  end

  it 'manda el enlace por la última conversación del cliente' do
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    quote = create_quote
    post "#{url}/#{quote['id']}/deliver", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(conversation.messages.last.content).to include(quote['public_url'])
    expect(response.parsed_body['quote']['status']).to eq('sent')
  end

  describe 'enlace del cliente' do
    it 'la ve (queda «Vista»), la acepta con su nombre y gana la oportunidad' do
      opp = opportunity
      quote = Quote.find(create_quote(admin, opportunity_id: opp.id)['id'])
      Quotes::StatusService.new(quote).apply!('sent')
      get "/cotizacion/#{quote.public_token}"
      expect(response.body).to include('COT-0001')
      expect(quote.reload.viewed_at).to be_present

      post "/cotizacion/#{quote.public_token}/aceptar", params: { accepted_by_name: 'Jane' }
      expect(quote.reload).to be_won
      expect(quote.accepted_by_name).to eq('Jane')
      expect(opp.reload.outcome).to eq('won')
    end

    it 'la rechaza con comentario' do
      quote = Quote.find(create_quote['id'])
      Quotes::StatusService.new(quote).apply!('sent')
      post "/cotizacion/#{quote.public_token}/rechazar", params: { comment: 'Muy cara' }
      expect(quote.reload).to be_lost
      expect(quote.outcome_note).to include('Muy cara')
    end
  end

  describe 'ligar a una oportunidad' do
    def link(quote, params)
      post "#{url}/#{quote['id']}/link_opportunity", params: params, headers: admin.create_new_auth_token, as: :json
      response
    end

    it 'se liga, se cambia y se quita mientras no esté cerrada' do
      quote = create_quote
      first = opportunity
      second = opportunity(title: 'Instalación')
      expect(link(quote, opportunity_id: first.id).parsed_body['quote']['opportunity']['id']).to eq(first.id)
      expect(link(quote, opportunity_id: second.id).parsed_body['quote']['opportunity']['id']).to eq(second.id)
      expect(link(quote, {}).parsed_body['quote']['opportunity']).to be_nil
    end

    it 'ya cerrada no se cambia; y si la empresa la exige no se quita' do
      quote = create_quote
      link(quote, opportunity_id: opportunity.id)
      CaseSetting.for_account(account).update!(quotes_require_opportunity: true)
      expect(link(quote, {})).to have_http_status(:unprocessable_entity)

      move(quote, 'sent')
      move(quote, 'won')
      expect(link(quote, opportunity_id: opportunity(title: 'Otra').id)).to have_http_status(:unprocessable_entity)
    end

    it 'una nueva con «crear oportunidad» nace ligada' do
      venta
      quote = create_quote(admin, create_opportunity: true)
      expect(quote['opportunity']).to be_present
    end
  end
end
