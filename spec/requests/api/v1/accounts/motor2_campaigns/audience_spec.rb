# frozen_string_literal: true

require 'rails_helper'

# «A quién»: la página de la audiencia y «Descargar lista» (CSV).
RSpec.describe 'Motor2 campaigns › A quién' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:api) { "/api/v1/accounts/#{account.id}/motor2_campaigns" }
  let(:payload) { [{ attribute_key: 'name', filter_operator: 'contains', values: ['Cliente'], query_operator: nil, attribute_model: 'standard' }] }

  before { 3.times { |i| create(:contact, account: account, name: "Cliente #{i}", email: "c#{i}@ejemplo.com") } }

  it 'regresa la página y el CSV de lo filtrado' do
    post "#{api}/preview", params: { payload: payload, inbox_id: inbox.id, per_page: 10, q: 'Cliente 2' },
                           headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('matching' => 1, 'page' => 1)
    expect(response.parsed_body['contacts'].pluck('name')).to eq(['Cliente 2'])

    post "#{api}/preview_csv", params: { payload: payload, inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.media_type).to eq('text/csv')
    expect(response.body.lines.size).to eq(4)
  end
end
