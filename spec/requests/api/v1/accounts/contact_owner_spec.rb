# frozen_string_literal: true

require 'rails_helper'

# Ficha del contacto › Responsable fijo.
RSpec.describe 'Contact Owner API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox)   { create(:inbox, account: account, name: 'WhatsApp Ventas') }
  let(:url)     { "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/owner" }

  it 'el Supervisor lo pone y avisa en qué bandejas del contacto no está' do
    create(:contact_inbox, contact: contact, inbox: inbox)
    patch url, params: { owner_id: agent.id }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['owner']['id']).to eq(agent.id)
    expect(body['missing_inboxes']).to eq(['WhatsApp Ventas'])
    expect(contact.reload.owner_id).to eq(agent.id)
  end

  it 'se quita mandándolo vacío' do
    contact.update!(owner: agent)
    patch url, params: { owner_id: '' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['owner']).to be_nil
    expect(contact.reload.owner_id).to be_nil
  end

  it 'sin «Asignar a otra persona» se ve pero no se cambia' do
    seller = AccessRole.for_account(account).find { |role| role.key == 'seller' }
    account.account_users.find_by(user: agent).update!(access_role: seller)
    contact.update!(owner: agent)

    get url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['can_edit']).to be(false)

    patch url, params: { owner_id: admin.id }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'rechaza a alguien de otra cuenta' do
    patch url, params: { owner_id: create(:user).id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
