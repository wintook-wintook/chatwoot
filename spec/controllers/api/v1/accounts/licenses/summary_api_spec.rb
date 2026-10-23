# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F4)
RSpec.describe 'Licenses summary API', type: :request do
  let(:wintook) { create(:account, custom_attributes: { 'wintook_internal' => true }) }
  let(:lector) { create(:user, account: wintook, role: :agent, custom_attributes: { 'can_view_licenses' => true }) }

  it 'devuelve indicadores, vencimientos y planes a quien puede ver licencias' do
    get "/api/v1/accounts/#{wintook.id}/licenses/summary", headers: lector.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.keys).to contain_exactly('kpis', 'expirations', 'by_plan')
  end

  it 'misma puerta que el resto: sin permiso, 401' do
    otro = create(:user, account: wintook, role: :administrator)

    get "/api/v1/accounts/#{wintook.id}/licenses/summary", headers: otro.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
