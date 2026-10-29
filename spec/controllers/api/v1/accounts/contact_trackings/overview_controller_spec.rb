# frozen_string_literal: true

require 'rails_helper'

# §10.12 (U5) — el embudo del tablero general cuenta igual que el de campañas.
RSpec.describe 'Api::V1::Accounts::ContactTrackings::Overview', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  def tracking(attrs = {})
    create(:contact_tracking, { account: account, inbox: inbox, contact: create(:contact, account: account) }.merge(attrs))
  end

  it 'respondió / interesado: la IA o la palabra clave, cada uno una vez' do
    tracking(last_intent: 'tracking', interested_at: Time.current) # solo palabra clave (como antes)
    tracking(prospect_stage: 'interested') # solo la IA
    tracking(last_intent: 'tracking', prospect_stage: 'handed_off', interested_at: Time.current) # las dos
    tracking(booked_at: Time.current)
    tracking

    get "/api/v1/accounts/#{account.id}/contact_trackings/overview", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['funnel']).to eq('created' => 5, 'replied' => 3, 'interested' => 3, 'appointment' => 1)
  end
end
