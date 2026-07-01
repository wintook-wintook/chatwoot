# frozen_string_literal: true

require 'rails_helper'

# @campanas_vendedor — eje de ENTREGA (WhatsApp) separado del de ejecución.
RSpec.describe 'Tracking Campaigns API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox) }

  # Crea un prospecto con conversación cuyo último mensaje saliente tiene el status dado.
  def prospect_with_delivery(message_status)
    contact = create(:contact, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, status: message_status)
    create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                              tracking_campaign_id: campaign.id, conversation: conversation)
  end

  describe 'GET /api/v1/accounts/{account.id}/tracking_campaigns/{id}' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      before do
        prospect_with_delivery('delivered')
        prospect_with_delivery('read')  # cuenta como entregado
        prospect_with_delivery('sent')  # sin confirmar
        prospect_with_delivery('failed')
        # prospecto sin conversación: no cuenta en el eje de entrega
        create(:contact_tracking, account: account, contact: create(:contact, account: account),
                                  inbox: inbox, tracking_campaign_id: campaign.id)
      end

      it 'expone el eje de entrega con 3 buckets basado en el último mensaje saliente' do
        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        delivery = response.parsed_body['delivery']
        expect(delivery).to eq('delivered' => 2, 'sent' => 1, 'failed' => 1)
      end

      it 'mantiene el eje de ejecución (stats) separado de la entrega' do
        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response.parsed_body['stats']['total']).to eq(5)
      end
    end
  end
end
