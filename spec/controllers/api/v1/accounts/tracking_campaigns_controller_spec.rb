# frozen_string_literal: true

require 'rails_helper'

# @campanas_vendedor — eje de ENTREGA (WhatsApp) separado del de ejecución.
RSpec.describe 'Tracking Campaigns API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox) }

  # Crea un prospecto con conversación cuyo último mensaje saliente tiene el status dado.
  def prospect_with_delivery(message_status, extra = {})
    contact = create(:contact, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, status: message_status)
    create(:contact_tracking, { account: account, contact: contact, inbox: inbox,
                                tracking_campaign_id: campaign.id, conversation: conversation }.merge(extra))
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

    context 'when contacts have replied' do
      before do
        # respondió + la regla Interesado lo marcó
        prospect_with_delivery('delivered', last_intent: 'tracking', interested_at: 1.hour.ago)
        # la IA dice interesado y tiene cita de calendario, pero ninguna regla lo marcó: no cuenta
        prospect_with_delivery('delivered', last_intent: 'interested', appointment_at: 1.day.from_now)
        # respondió + reglas Interesado y Agendó
        prospect_with_delivery('read', last_intent: 'tracking', interested_at: 2.hours.ago, booked_at: 1.hour.ago)
        # no respondió (last_intent nil)
        prospect_with_delivery('sent')
      end

      it 'cuenta pausados/cancelados solo si los dejó así una regla de palabra clave' do
        prospect_with_delivery('sent', status: 'paused', keyword_action_fired: { 'action' => 'pause', 'keyword' => '#pausar' })
        prospect_with_delivery('sent', status: 'paused') # pausado a mano: no cuenta
        prospect_with_delivery('sent', status: 'active', keyword_action_fired: { 'action' => 'pause' }) # ya se reanudó
        prospect_with_delivery('sent', status: 'cancelled', keyword_action_fired: { 'action' => 'cancel', 'keyword' => '#cancelar' })
        prospect_with_delivery('sent', status: 'cancelled') # cancelado al borrar o desde la UI: no cuenta

        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response.parsed_body['funnel']).to include('paused_rule' => 1, 'cancelled_rule' => 1)
      end

      it 'expone el embudo: interesados / agendaron solo por las reglas de palabra clave' do
        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response.parsed_body['funnel']).to eq('replied' => 3, 'interested' => 2, 'appointment' => 1, 'objective_met' => 0,
                                                     'paused_rule' => 0, 'cancelled_rule' => 0)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/tracking_campaigns/{id}' do
    def campaign_tracking(status)
      create(:contact_tracking, account: account, contact: create(:contact, account: account), inbox: inbox,
                                tracking_campaign_id: campaign.id, status: status)
    end

    # Caso real (campañas 17 y 57): 2 plantillas WhatsApp para 3 intentos no pasa la
    # validación; antes cancel! no lo guardaba y quedaba vivo, sin campaña.
    def invalid_tracking
      campaign_tracking('pending').tap do |tracking|
        tracking.update_columns(whatsapp_templates: %w[uno dos], max_attempts: 3) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    it 'cancela los seguimientos programados de la campaña, aunque no pasen la validación, y la borra' do
      pending_one = campaign_tracking('pending')
      scheduled = campaign_tracking('scheduled')
      invalid = invalid_tracking
      completed = campaign_tracking('completed')

      delete "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:no_content)
      expect(TrackingCampaign.exists?(campaign.id)).to be(false)
      expect([pending_one, scheduled, invalid].map { |t| t.reload.status }).to all(eq('cancelled'))
      expect(completed.reload.status).to eq('completed')
    end

    it 'si algún seguimiento sigue vivo, no borra la campaña' do
      tracking = campaign_tracking('pending')
      allow_any_instance_of(ContactTracking).to receive(:cancel!).and_return(false) # rubocop:disable RSpec/AnyInstance

      delete "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(TrackingCampaign.exists?(campaign.id)).to be(true)
      expect(tracking.reload.tracking_campaign_id).to eq(campaign.id)
    end
  end
end
