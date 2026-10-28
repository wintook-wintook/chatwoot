require 'rails_helper'

# feat/apariencia B1 — logo y color de la empresa.
RSpec.describe 'Account brand', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/brand" }
  let(:logo) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  it 'lets an administrator choose the color and upload the logo', :aggregate_failures do
    patch url, params: { tint: 'bosque', logo: logo }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['tint']).to eq('bosque')
    expect(response.parsed_body['logo_url']).to include('/rails/active_storage/')
    expect(account.reload.brand_tint).to eq('bosque')

    delete url, headers: admin.create_new_auth_token
    expect(response.parsed_body['logo_url']).to be_nil
    expect(account.reload.brand_logo).not_to be_attached
  end

  it 'rejects an unknown color and does not let agents change it', :aggregate_failures do
    patch url, params: { tint: 'neon' }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)

    patch url, params: { tint: 'rosa' }, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    expect(account.reload.brand_tint).to eq('default')
  end

  it 'sends the brand with the account' do
    account.update!(custom_attributes: { 'brand_tint' => 'rosa' })
    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['brand']).to include('tint' => 'rosa', 'logo_url' => nil)
  end
end
