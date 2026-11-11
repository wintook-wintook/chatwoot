# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q3.1 — parámetros de CrmZeus de la cuenta.
RSpec.describe 'CrmZeus Settings API' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/settings" }

  it 'sin renglón devuelve los de omisión y no lo crea' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['settings']).to eq('require_delivery_date' => false)
    expect(CrmSetting.where(account: account)).not_to exist
  end

  it 'el Administrador los cambia y los catálogos los traen' do
    patch url, params: { settings: { require_delivery_date: true } }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['settings']).to eq('require_delivery_date' => true)
    get "/api/v1/accounts/#{account.id}/crm/catalogs", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['settings']).to eq('require_delivery_date' => true)
  end

  it 'un agente no los cambia' do
    patch url, params: { settings: { require_delivery_date: true } }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(CrmSetting.where(account: account)).not_to exist
  end
end
