# frozen_string_literal: true

require 'rails_helper'

# «Redactar con Dali» en la campaña: regresa la propuesta (no guarda) o el error.
RSpec.describe 'Motor2 campaigns › Redactar con Dali' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'saved', tracking_template: seller, user: admin,
                                       brief: { 'kind' => 'offer', 'offer_what' => 'Promo' }, touches: { 'attempts' => 2 })
  end
  let(:url) { "/api/v1/accounts/#{account.id}/motor2_campaigns/#{campaign.id}/copy" }

  it 'regresa el texto que escribió Dali' do
    allow_any_instance_of(TrackingCampaigns::CopyWriter).to receive(:call).and_return(text: '🔥 *Promo*') # rubocop:disable RSpec/AnyInstance
    post url, params: { target: 'info', tone: 'cercano' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('text' => '🔥 *Promo*')
  end

  it 'sin OpenAI en la cuenta, lo dice' do
    post url, params: { target: 'info' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('OpenAI')
  end
end
