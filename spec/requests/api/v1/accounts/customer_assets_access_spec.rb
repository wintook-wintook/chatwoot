# frozen_string_literal: true

require 'rails_helper'

# Equipos de clientes — quien solo puede «Ver» los consulta, pero no los da de alta ni
# los cambia.
RSpec.describe 'Equipos de clientes (permisos)' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:base) { "/api/v1/accounts/#{account.id}/customer_assets" }

  def give(areas)
    role = AccessRole.for_account(account).find { |r| r.key == 'viewer' }
    role.update!(areas: role.areas.merge(areas))
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def create_asset
    post base, params: { customer_asset: { contact_id: contact.id, name: 'Minisplit' } },
               headers: user.create_new_auth_token, as: :json
  end

  it 'con Clientes en «Ver» lista, pero no crea ni cambia' do
    asset = CustomerAsset.create!(account: account, contact: contact, name: 'Bomba')
    give('clients' => 'view', 'service' => 'none', 'sales' => 'none')

    get base, params: { contact_id: contact.id }, headers: user.create_new_auth_token
    expect(response).to have_http_status(:success)

    create_asset
    expect(response).to have_http_status(:forbidden)

    patch "#{base}/#{asset.id}", params: { customer_asset: { name: 'Otra' } }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(asset.reload.name).to eq('Bomba')
  end

  it 'con Clientes en «Solo lo suyo» sí crea' do
    give('clients' => 'own')

    create_asset
    expect(response).to have_http_status(:created)
  end
end
