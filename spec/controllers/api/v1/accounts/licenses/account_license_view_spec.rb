# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F5) — lo que la propia cuenta ve de su licencia
RSpec.describe 'La cuenta y su licencia', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'sin licencia no manda nada (fuera de licencia)' do
    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['license']).to be_nil
  end

  it 'con licencia manda el periodo actual, los agentes usados y el siguiente' do
    create(:account_license, account: account, name: 'Profesional', max_agents: 5, expires_at: 8.days.from_now)
    create(:account_license, account: account, name: 'Profesional', status: :scheduled, max_agents: 6)

    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token, as: :json

    license = response.parsed_body['license']
    expect(license).to include('state' => 'paid', 'agents_count' => 1)
    expect(license['current']).to include('name' => 'Profesional', 'max_agents' => 5, 'days_left' => 8)
    expect(license['next']).to include('max_agents' => 6)
  end

  it 'el usuario sabe si su cuenta venció por licencia (para la pantalla de suspendida)' do
    create(:account_license, account: account, status: :expired)

    get '/api/v1/profile', headers: admin.create_new_auth_token, as: :json

    cuenta = response.parsed_body['accounts'].find { |a| a['id'] == account.id }
    expect(cuenta['license_expired']).to be(true)
  end
end
