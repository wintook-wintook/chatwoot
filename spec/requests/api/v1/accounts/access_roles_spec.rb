# frozen_string_literal: true

require 'rails_helper'

# Plan-Roles-Permisos P3 — Ajustes › Roles y el combo «Rol» de Editar agente.
RSpec.describe 'Access Roles API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/access_roles" }

  def seller
    AccessRole.for_account(account).find { |role| role.key == 'seller' }
  end

  it 'lista los 4 roles con cuántos agentes los usan (sin rol = Supervisor)' do
    agent
    get url, headers: admin.create_new_auth_token, as: :json
    roles = response.parsed_body['access_roles']
    expect(roles.pluck('key')).to eq(%w[supervisor seller technician viewer])
    expect(roles.first['agents_count']).to eq(1)
    expect(roles.first['customized']).to be(false)
  end

  it 'se edita directo y se restaura como venía' do
    patch "#{url}/#{seller.id}", params: { areas: { service: 'own' }, actions: { export: true } },
                                 headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['access_role']['areas']['service']).to eq('own')
    expect(response.parsed_body['access_role']['customized']).to be(true)

    post "#{url}/#{seller.id}/restore", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['access_role']['areas']['service']).to eq('none')
    expect(response.parsed_body['access_role']['actions']['export']).to be(false)
  end

  it 'rechaza niveles desconocidos' do
    patch "#{url}/#{seller.id}", params: { areas: { service: 'medio' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'solo el administrador' do
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'el administrador le cambia el rol a un agente' do
    patch "/api/v1/accounts/#{account.id}/agents/#{agent.id}", params: { agent: { access_role_key: 'seller' } },
                                                               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['access_role_key']).to eq('seller')
    expect(account.account_users.find_by(user: agent).access_role.key).to eq('seller')
  end
end
