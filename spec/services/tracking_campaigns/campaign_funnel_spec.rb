# frozen_string_literal: true

require 'rails_helper'

# §10.12 (U2) — un solo embudo para todas las campañas: IA (V5) + palabras clave del agente.
RSpec.describe TrackingCampaigns::CampaignFunnel do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox, daily_cap: 30) }

  def prospect(attrs = {})
    create(:contact_tracking, { account: account, inbox: inbox, tracking_campaign: campaign,
                                contact: create(:contact, account: account) }.merge(attrs))
  end

  it 'cuenta etapas y salidas de la IA' do
    prospect(attempt_count: 0)
    prospect(attempt_count: 1, status: 'scheduled')
    prospect(attempt_count: 1, prospect_stage: 'replied', prospect_exit: 'not_now')
    prospect(attempt_count: 2, prospect_stage: 'interested')
    prospect(attempt_count: 1, prospect_stage: 'handed_off')
    prospect(attempt_count: 1, prospect_stage: 'replied', prospect_exit: 'not_interested', status: 'completed')
    prospect(attempt_count: 3, status: 'completed')
    prospect(attempt_count: 1, prospect_exit: 'opted_out', status: 'cancelled')

    expect(described_class.for(campaign)).to include(
      total: 8, contacted: 7, replied: 4, interested: 2, handed_off: 1,
      not_now: 1, not_interested: 1, wrong_person: 0, opted_out: 1, bounced: 0, no_reply: 1
    )
  end

  # D27: una campaña que solo tiene marcas de palabra clave (sin IA) da lo mismo que «Intenciones»
  it 'las palabras clave cuentan igual que en «Intenciones»: ningún número baja' do
    prospect(attempt_count: 1, last_intent: 'tracking', interested_at: Time.current)
    prospect(attempt_count: 1, last_intent: 'tracking', booked_at: Time.current, status: 'objective_met')
    prospect(attempt_count: 1, last_intent: 'tracking', status: 'paused', keyword_action_fired: { 'action' => 'pause' })
    prospect(attempt_count: 1, status: 'cancelled', keyword_action_fired: { 'action' => 'cancel' })

    expect(described_class.for(campaign)).to include(
      replied: 3, interested: 1, appointment: 1, objective_met: 1, paused_rule: 1, cancelled_rule: 1
    )
  end

  it 'IA y palabra clave sobre el mismo prospecto cuentan una sola vez' do
    prospect(attempt_count: 1, last_intent: 'tracking', prospect_stage: 'interested', interested_at: Time.current)

    expect(described_class.for(campaign)).to include(replied: 1, interested: 1)
  end

  it 'quien respondió antes de la IA (solo last_intent) no cuenta como «sin respuesta»' do
    prospect(attempt_count: 3, last_intent: 'tracking', status: 'completed')

    expect(described_class.for(campaign)).to include(replied: 1, no_reply: 0)
  end

  it 'por varias campañas a la vez' do
    other = create(:tracking_campaign, account: account, inbox: inbox)
    prospect(attempt_count: 1)

    result = described_class.by_campaign([campaign.id, other.id])
    expect(result[campaign.id][:contacted]).to eq(1)
    expect(result[other.id]).to eq(described_class::EMPTY)
  end
end
