# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F0) — el 402 de siempre, con el tope que pone la licencia
RSpec.describe 'Agents API con licencia', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:params) { { name: 'NewUser', email: Faker::Internet.email, role: :agent } }

  before { allow(Licenses::Enforcement).to receive(:enabled?).and_return(true) }

  it 'no deja pasar del tope de la licencia, y no expulsa a nadie' do
    create(:account_license, account: account, max_agents: 2)
    create(:user, account: account, role: :agent)

    post "/api/v1/accounts/#{account.id}/agents", params: params, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:payment_required)
    expect(account.users.count).to eq(2)
  end

  it 'con lugar en la licencia, da de alta' do
    create(:account_license, account: account, max_agents: 5)

    post "/api/v1/accounts/#{account.id}/agents", params: params, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end
end
