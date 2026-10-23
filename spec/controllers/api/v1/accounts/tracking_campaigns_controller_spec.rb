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

      it 'sin envíos registrados (antes de la Fase 1), la entrega sale del último mensaje saliente' do
        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        delivery = response.parsed_body['delivery']
        expect(delivery).to eq('delivered' => 2, 'sent' => 1, 'unconfirmed' => 0, 'retrying' => 0, 'failed' => 1,
                               'failure_reasons' => [])
      end

      # proyecto@automatizacion_campanas — Fase 1: el último envío registrado del seguimiento manda.
      it 'con envíos registrados usa el último de cada seguimiento y desglosa los motivos de fallo' do
        record = lambda do |tracking, status, **extra|
          TrackingDelivery.create!(account: account, contact_tracking: tracking, tracking_campaign: campaign,
                                   kind: 'template', attempt_number: 1, status: status, **extra)
        end
        trackings = campaign.contact_trackings.where.not(conversation_id: nil).order(:id).to_a
        record.call(trackings[0], 'failed', error_code: '131026', error_title: 'Message undeliverable')
        record.call(trackings[0], 'read') # el último manda: entregado
        record.call(trackings[1], 'unconfirmed')
        record.call(trackings[2], 'failed', error_code: '130429', error_title: 'Rate limit', next_retry_at: 5.minutes.from_now)
        record.call(trackings[3], 'failed', error_code: '131026', error_title: 'Message undeliverable')

        get "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response.parsed_body['delivery']).to eq(
          'delivered' => 1, 'sent' => 0, 'unconfirmed' => 1, 'retrying' => 1, 'failed' => 1,
          'failure_reasons' => [{ 'code' => '131026', 'title' => 'Message undeliverable', 'count' => 1 }]
        )
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

  describe 'POST /api/v1/accounts/{account.id}/tracking_campaigns (continua)' do
    let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }

    it 'con launch: false la guarda sin ponerla en curso' do
      post "/api/v1/accounts/#{account.id}/tracking_campaigns",
           params: { name: 'Octubre', tracking_template_id: template.id, launch: false },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(TrackingCampaign.find(response.parsed_body['campaign_id'])).to have_attributes(status: 'saved', mode: 'continuous')
    end
  end

  describe 'PATCH una campaña Guardada' do
    let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
    let(:other_template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
    let(:contacts) { create_list(:contact, 2, account: account) }
    let(:saved) do
      create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, mode: 'batch',
                                 status: 'saved', scheduled_for: 1.day.from_now, ends_at: 3.days.from_now,
                                 audience: { filter_payload: [], excluded_contact_ids: [], skip_active: true })
    end

    before do
      allow_any_instance_of(ContactTrackings::BulkAssignService) # rubocop:disable RSpec/AnyInstance
        .to receive(:resolve_contacts).and_return(Contact.where(id: contacts.map(&:id)))
    end

    it 'por lote: cambia sus datos y la audiencia, sigue Guardada y no inscribe a nadie' do
      expect(ContactTrackings::BulkAssignJob).not_to receive(:perform_later)
      start = 2.days.from_now.change(usec: 0)

      patch "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/#{saved.id}",
            params: { campaign_name: 'Lote nuevo', template_id: other_template.id, scheduled_for: start.iso8601,
                      payload: [{ attribute_key: 'labels', filter_operator: 'equal_to', values: ['vip'] }],
                      excluded_contact_ids: [contacts.first.id], audience_source: { type: 'label', label: 'vip' } },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(saved.reload).to have_attributes(name: 'Lote nuevo', tracking_template_id: other_template.id, status: 'saved',
                                              scheduled_for: start, ends_at: nil)
      expect(saved.audience).to include('excluded_contact_ids' => [contacts.first.id],
                                        'source' => { 'type' => 'label', 'label' => 'vip' })
    end

    it 'por lote: acepta un inicio que ya pasó (al ponerla en curso empieza ahora), no un fin vencido' do
      url = "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/#{saved.id}"
      body = { campaign_name: 'Lote', template_id: template.id, scheduled_for: 1.hour.ago.iso8601 }

      patch url, params: body, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(saved.reload.status).to eq('saved')

      patch url, params: body.merge(ends_at: 1.minute.ago.iso8601), headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('El fin ya pasó')
    end

    it 'puede pasar de por lote a continua' do
      patch "/api/v1/accounts/#{account.id}/tracking_campaigns/#{saved.id}",
            params: { name: 'Ahora continua', tracking_template_id: template.id, daily_cap: 20 },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(saved.reload).to have_attributes(mode: 'continuous', status: 'saved', daily_cap: 20, audience: {})
      expect(saved.accepting_entries?).to be(false)
    end

    it 'ya puesta en curso no se modifica' do
      running = create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, name: 'Corre')

      patch "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/#{running.id}",
            params: { campaign_name: 'Otro', template_id: template.id, scheduled_for: 1.day.from_now.iso8601 },
            headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "/api/v1/accounts/#{account.id}/tracking_campaigns/#{running.id}",
            params: { name: 'Otro', tracking_template_id: template.id },
            headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(running.reload.name).to eq('Corre')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/tracking_campaigns/{id}/launch' do
    let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }

    it 'pone en curso una continua Guardada' do
      saved = create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template,
                                         mode: 'continuous', status: 'saved', scheduled_for: 1.hour.ago)

      post "/api/v1/accounts/#{account.id}/tracking_campaigns/#{saved.id}/launch",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('running')
    end

    it 'una que ya corre devuelve 422' do
      post "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}/launch",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
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

  # proyecto@automatizacion_campanas — reanudar una campaña pausada por error de Meta
  describe 'POST /api/v1/accounts/{account.id}/tracking_campaigns/{id}/resume' do
    it 'reanuda la campaña pausada y devuelve su estado y los seguimientos a reanudar' do
      TrackingCampaigns::Pause.new(campaign, reason: 'Meta 131042: payment issue').perform

      post "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}/resume",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('campaign_id' => campaign.id, 'trackings' => 0)
      expect(campaign.reload.paused_reason).to be_nil
    end

    it 'una campaña que no está pausada responde 422' do
      post "/api/v1/accounts/#{account.id}/tracking_campaigns/#{campaign.id}/resume",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
