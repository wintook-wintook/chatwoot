# frozen_string_literal: true

require 'rails_helper'

# @campanas_vendedor / proyecto@bulk_tracking_assign
RSpec.describe 'Contact Tracking Bulk Assigns API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:sms_channel) { create(:channel_sms, account: account) }
  let(:inbox) { sms_channel.inbox }
  let(:template) { create(:tracking_template, account: account, inbox: inbox) }
  let(:match_all_payload) do
    [{ 'attribute_key' => 'blocked', 'filter_operator' => 'equal_to', 'values' => [false], 'query_operator' => nil }]
  end

  describe 'POST /api/v1/accounts/{account.id}/contact_tracking_bulk_assigns/preview' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/preview"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      let!(:ready_contact) { create(:contact, :with_phone_number, account: account) }
      let!(:unreachable_contact) { create(:contact, account: account) }

      it 'returns the classified buckets with counts' do
        post "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/preview",
             headers: admin.create_new_auth_token,
             params: { payload: match_all_payload, template_id: template.id, skip_active: true },
             as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['channel']['channel_type']).to eq('Channel::Sms')
        expect(body['counts']).to include('ready' => 1, 'unreachable' => 1, 'total' => 2)
        reasons = body['contacts'].to_h { |c| [c['id'], c['reason']] }
        expect(reasons[unreachable_contact.id]).to eq('NO_PHONE')
        expect(reasons[ready_contact.id]).to be_nil
      end

      it 'returns 422 when the template has no inbox' do
        no_inbox_template = create(:tracking_template, account: account, inbox: nil)

        post "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns/preview",
             headers: admin.create_new_auth_token,
             params: { payload: match_all_payload, template_id: no_inbox_template.id },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/no tiene un inbox configurado/)
      end
    end
  end

  # prospeccion V3 (docs/prospeccion_estudio.md §10.2) — reglas de una campaña de prospección.
  describe 'POST /api/v1/accounts/{account.id}/contact_tracking_bulk_assigns (Prospección)' do
    let(:url) { "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns" }
    let(:body) do
      { payload: match_all_payload, template_id: template.id, campaign_name: 'Frío', purpose: 'prospecting',
        scheduled_for: 1.hour.from_now.iso8601, respect_working_hours: false }
    end

    before { create(:contact, :with_phone_number, account: account) }

    # §10.12 (D21): fuera de correo el tope es opcional; «días hábiles» es casilla
    it 'en SMS el tope es opcional; si viene, de 1 a 500' do
      post url, params: body, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)

      post url, params: body.merge(daily_cap: 501), headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['error']).to include('va de 1 a 500')
    end

    it 'con tope la crea con su tope y respeta la casilla de horario' do
      post url, params: body.merge(daily_cap: 30), headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(TrackingCampaign.find(response.parsed_body['campaign_id']))
        .to have_attributes(purpose: 'prospecting', daily_cap: 30, respect_working_hours: false)
    end

    it 'guarda las casillas de qué hacer con la respuesta; por omisión, prendidas (D20, D25)' do
      post url, params: body.merge(stop_when_not_interested: false), headers: admin.create_new_auth_token, as: :json

      expect(TrackingCampaign.find(response.parsed_body['campaign_id']))
        .to have_attributes(stop_when_not_interested: false, stop_when_wrong_person: true, retry_not_now: true)
    end

    # prospeccion P3
    it 'guarda el asunto B de la prueba A/B' do
      post url, params: body.merge(daily_cap: 30, email_subject: 'Asunto A', email_subject_b: ' Asunto B '),
                headers: admin.create_new_auth_token, as: :json

      expect(TrackingCampaign.find(response.parsed_body['campaign_id']).email_subject_b).to eq('Asunto B')
    end
  end
end
