# frozen_string_literal: true

require 'rails_helper'

# «Terminar campaña»: Terminada sin vuelta, cancela lo que faltaba por salir, la plática en curso sigue.
RSpec.describe TrackingCampaigns::Finish do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Renovaciones', engine: '2', status: 'running', mode: 'continuous', user: admin,
                                       inbox: inbox, scheduled_for: 1.day.ago, brief: { 'kind' => 'renew' }, touches: { 'attempts' => 3 })
  end

  def tracking(status)
    ContactTracking.create!(account: account, contact: create(:contact, account: account), inbox: inbox, tracking_campaign: campaign,
                            scheduled_for: 1.hour.from_now, status: status, max_attempts: 3, objective: 'Recordar')
  end

  it 'la termina, cancela lo pendiente y deja la plática en curso' do
    waiting = tracking('scheduled')
    talking = tracking('active')
    expect(described_class.new(campaign).perform).to eq(1)
    expect(campaign.reload).to have_attributes(status: 'finished')
    expect(campaign.accepting_entries?).to be(false)
    expect(waiting.reload.status).to eq('cancelled')
    expect(talking.reload.status).to eq('active')
    expect(described_class.new(campaign).perform).to be_nil
    expect((TrackingCampaigns::Resume.new(campaign).call.try(:[], :campaign) || campaign).reload.status).to eq('finished')
  end

  it 'por la API', type: :request do
    post "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}/finish",
         headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'finished', 'cancelled' => 0)
  end
end
