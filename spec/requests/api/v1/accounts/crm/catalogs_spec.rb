# frozen_string_literal: true

require 'rails_helper'

# CrmZeus O1 — API de catálogos de organizaciones.
RSpec.describe 'CrmZeus Catalogs API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:base)    { "/api/v1/accounts/#{account.id}/crm" }

  it 'la primera vez precarga los catálogos base y los entrega juntos' do
    account.crm_lookups.create!(kind: :rating, name: 'Cliente Oro')
    account.crm_lookups.create!(kind: :rating, name: 'Viejo', active: false)

    get "#{base}/catalogs", headers: agent.create_new_auth_token, as: :json
    body = response.parsed_body
    expect(body['lookups']['rating'].pluck('name')).to eq(['Cliente Oro'])
    expect(body['lookups'].keys).to include('customer_type', 'zone', 'collector')
    expect(body['currencies'].pluck('iso_code')).to eq(['MXN'])
    expect(body['payment_terms'].pluck('name')).to eq(['Contado'])
    expect(body['countries'].first['states'].size).to eq(32)
    expect(body['can_admin']).to be(false)

    get "#{base}/catalogs", params: { all: 'true' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['lookups']['rating'].size).to eq(2)
  end

  it 'solo el Administrador da de alta; el agente solo consulta' do
    post "#{base}/lookups", params: { lookup: { kind: 'industry', name: 'Ferretería' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)

    post "#{base}/lookups", params: { lookup: { kind: 'industry', name: 'Ferretería' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)

    get "#{base}/lookups", params: { kind: 'industry' }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['items'].pluck('name')).to eq(['Ferretería'])
  end

  it 'no borra lo que ya usa una organización y no cambia el catálogo de un valor' do
    zone = account.crm_lookups.create!(kind: :zone, name: 'Norte')
    account.crm_organizations.create!(legal_name: 'X', trade_name: 'X', zone: zone)

    delete "#{base}/lookups/#{zone.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('desactívalo')

    patch "#{base}/lookups/#{zone.id}", params: { lookup: { kind: 'rating', active: false } }, headers: admin.create_new_auth_token, as: :json
    expect(zone.reload).to have_attributes(kind: 'zone', active: false)
  end

  it 'condiciones de pago con plazos' do
    post "#{base}/payment_terms",
         params: { payment_term: { name: '3 pagos', installments_attributes: [{ days: 0, percent: 30 }, { days: 15, percent: 35 },
                                                                              { days: 30, percent: 35 }] } },
         headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['item']).to include('credit_days' => 30)

    post "#{base}/payment_terms", params: { payment_term: { name: 'Mal', installments_attributes: [{ days: 10, percent: 50 }] } },
                                  headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['message']).to include('sumar 100')
  end

  it 'vendedores y monedas' do
    post "#{base}/sellers", params: { seller: { name: 'Alberto', user_id: agent.id } }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['item']).to include('user_name' => agent.name)

    post "#{base}/currencies", params: { currency: { name: 'Dólar', iso_code: 'usd', fixed_exchange_rate: 20 } },
                               headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['item']).to include('iso_code' => 'USD', 'fixed_exchange_rate' => 20.0)
  end

  it 'busca ciudades por las primeras letras y las da de alta al vuelo' do
    get "#{base}/catalogs", headers: agent.create_new_auth_token, as: :json
    coahuila = response.parsed_body['countries'].first['states'].find { |s| s['abbreviation'] == 'COA' }

    post "#{base}/cities", params: { city: { name: 'Torreón', state_id: coahuila['id'] } }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['city']['full_name']).to eq('Torreón, COA, México')

    get "#{base}/cities", params: { q: 'tor' }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['cities'].pluck('name')).to eq(['Torreón'])
  end

  describe 'países y estados' do
    before { Crm::DefaultCatalogs.ensure!(account) }

    let(:mexico) { account.crm_countries.find_by!(iso_code: 'MEX') }

    it 'el Administrador da de alta un país y sus estados; el agente solo consulta' do
      post "#{base}/countries", params: { country: { name: 'Guatemala', abbreviation: 'GT', iso_code: 'GTM' } },
                                headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      post "#{base}/countries", params: { country: { name: 'Guatemala', abbreviation: 'GT', iso_code: 'gtm' } },
                                headers: admin.create_new_auth_token, as: :json
      guatemala = response.parsed_body['item']
      expect(guatemala).to include('name' => 'Guatemala', 'iso_code' => 'GTM', 'states' => [])

      post "#{base}/states", params: { state: { name: 'Petén', abbreviation: 'PE', country_id: guatemala['id'] } },
                             headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['item']).to include('country_name' => 'Guatemala')

      get "#{base}/states", params: { country_id: mexico.id }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['items'].size).to eq(32)
    end

    it 'no deja crear un estado en el país de otra cuenta ni moverlo de país' do
      other = create(:account)
      Crm::DefaultCatalogs.ensure!(other)
      post "#{base}/states", params: { state: { name: 'Ajeno', country_id: other.crm_countries.first.id } },
                             headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      coahuila = mexico.states.find_by!(abbreviation: 'COA')
      guatemala = account.crm_countries.create!(name: 'Guatemala')
      patch "#{base}/states/#{coahuila.id}", params: { state: { name: 'Coahuila de Zaragoza', country_id: guatemala.id } },
                                             headers: admin.create_new_auth_token, as: :json
      expect(coahuila.reload).to have_attributes(name: 'Coahuila de Zaragoza', country_id: mexico.id)
    end

    it 'no borra un país o estado cuyas ciudades usa una dirección; si no se usan, se van con sus ciudades' do
      coahuila = mexico.states.find_by!(abbreviation: 'COA')
      torreon = coahuila.cities.create!(name: 'Torreón')
      org = account.crm_organizations.create!(legal_name: 'X', trade_name: 'X', home_address_attributes: { city_id: torreon.id })

      delete "#{base}/states/#{coahuila.id}", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['message']).to eq('Lo usa 1 dirección; no se puede borrar')
      delete "#{base}/countries/#{mexico.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      org.destroy!
      delete "#{base}/states/#{coahuila.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(CrmCity.exists?(torreon.id)).to be(false)
    end
  end
end
