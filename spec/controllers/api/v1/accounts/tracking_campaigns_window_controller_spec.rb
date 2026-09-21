# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F4: crear campañas con ventana
# (docs/automatizacion_campanas_plan.md §7.1).
RSpec.describe 'Tracking Campaigns API: ventana', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }

  describe 'POST /api/v1/accounts/{account.id}/tracking_campaigns (continua)' do
    def create_campaign(params)
      post "/api/v1/accounts/#{account.id}/tracking_campaigns", params: params, headers: admin.create_new_auth_token, as: :json
    end

    it 'sin inicio empieza ya, en curso, con su ventana y su tope' do
      ends = 30.days.from_now.change(usec: 0)
      create_campaign(name: 'Octubre', tracking_template_id: template.id, ends_at: ends.iso8601,
                      entry_delay_minutes: 60, respect_working_hours: false, daily_cap: 200)

      expect(response).to have_http_status(:success)
      campaign = account.tracking_campaigns.find(response.parsed_body['campaign_id'])
      expect(campaign).to have_attributes(mode: 'continuous', status: 'running', inbox_id: inbox.id,
                                          ends_at: ends, entry_delay_minutes: 60, respect_working_hours: false,
                                          daily_cap: 200, contact_trackings: [])
      expect(campaign.scheduled_for).to be_within(5.seconds).of(Time.current)
    end

    it 'con inicio futuro nace programada' do
      create_campaign(name: 'Noviembre', tracking_template_id: template.id, scheduled_for: 3.days.from_now.iso8601)

      expect(account.tracking_campaigns.last.status).to eq('draft')
    end

    it 'rechaza un fin anterior al inicio y un Agente IA sin inbox, con el motivo' do
      create_campaign(name: 'Mal', tracking_template_id: template.id, scheduled_for: 3.days.from_now.iso8601,
                      ends_at: 1.day.from_now.iso8601)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('posterior al inicio')

      create_campaign(name: 'Sin canal', tracking_template_id: create(:tracking_template, account: account).id)
      expect(response.parsed_body['error']).to include('no tiene un inbox')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/contact_tracking_bulk_assigns (por lote con ventana)' do
    let(:sms_channel) { create(:channel_sms, account: account) }
    let(:sms_template) { create(:tracking_template, account: account, inbox: sms_channel.inbox) }
    let(:payload) do
      [{ 'attribute_key' => 'blocked', 'filter_operator' => 'equal_to', 'values' => [false], 'query_operator' => nil }]
    end

    before { create(:contact, :with_phone_number, account: account) }

    it 'guarda el fin, la espera y el horario en la campaña, y la audiencia elegida' do
      starts = 1.day.from_now
      post "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns",
           params: { payload: payload, campaign_name: 'Lote', template_id: sms_template.id,
                     scheduled_for: starts.iso8601, ends_at: 5.days.from_now.iso8601,
                     entry_delay_minutes: 15, respect_working_hours: false },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      campaign = account.tracking_campaigns.find(response.parsed_body['campaign_id'])
      expect(campaign).to have_attributes(mode: 'batch', status: 'draft', entry_delay_minutes: 15,
                                          respect_working_hours: false)
      expect(campaign.ends_at).to be_within(1.second).of(5.days.from_now)
      expect(campaign.audience['filter_payload']).to eq(payload)
    end

    it 'rechaza un fin anterior al inicio' do
      post "/api/v1/accounts/#{account.id}/contact_tracking_bulk_assigns",
           params: { payload: payload, campaign_name: 'Lote', template_id: sms_template.id,
                     scheduled_for: 3.days.from_now.iso8601, ends_at: 1.day.from_now.iso8601 },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('El fin debe ser posterior al inicio')
    end
  end
end
