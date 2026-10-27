# frozen_string_literal: true

require 'rails_helper'

# prospeccion P4 (docs/prospeccion_estudio.md §10.11) — puntuación 0–100 del prospecto.
RSpec.describe TrackingCampaigns::ProspectScore do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox, purpose: 'prospecting', daily_cap: 30) }
  let(:contact) { create(:contact, account: account, custom_attributes: { 'ciudad' => 'Monterrey' }) }
  let(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: contact, tracking_campaign: campaign, status: 'active',
                              attempt_count: 1)
  end

  def score!
    described_class.call(tracking)
    tracking.reload
  end

  it 'sin reglas ni respuesta: 0 puntos' do
    expect(score!).to have_attributes(prospect_score: 0, prospect_score_parts: {})
    expect(tracking.prospect_scored_at).to be_present
  end

  it 'Interés con los pesos sugeridos: respondió +10, pidió precio +20, pidió cita +20' do
    tracking.update!(prospect_stage: 'interested', prospect_signals: %w[price meeting])

    expect(score!).to have_attributes(prospect_score: 50,
                                      prospect_score_parts: { 'replied' => 10, 'asked_price' => 20, 'asked_meeting' => 20 })
  end

  it 'agendar la cita cuenta como pedirla' do
    tracking.update!(prospect_stage: 'replied', booked_at: Time.current)

    expect(score!.prospect_score_parts).to include('asked_meeting' => 20)
  end

  it 'Perfil por reglas: etiqueta y atributo; «decide» lo infiere la IA si no hay regla (D17)' do
    contact.update!(label_list: ['Construccion'])
    tracking.update!(prospect_stage: 'replied', prospect_decision_maker: 'yes')
    campaign.update!(scoring: { 'rules' => { 'industry' => { 'labels' => ['construccion'] },
                                             'size' => { 'attribute_key' => 'ciudad', 'attribute_values' => ['monterrey'] } } })

    expect(score!).to have_attributes(prospect_score: 60,
                                      prospect_score_parts: { 'industry' => 20, 'size' => 15, 'decider' => 15, 'replied' => 10 })
  end

  it 'con regla de «decide», manda la regla aunque la IA diga que sí' do
    tracking.update!(prospect_decision_maker: 'yes')
    campaign.update!(scoring: { 'rules' => { 'decider' => { 'labels' => ['gerente'] } } })

    expect(score!.prospect_score_parts).not_to have_key('decider')
  end

  it 'los negativos bajan, nunca de 0; 30 días sin responder cuenta una vez (D18)' do
    tracking.update!(prospect_stage: 'replied', prospect_exit: 'not_now')
    expect(score!.prospect_score).to eq(0)
    expect(tracking.prospect_score_parts).to eq('replied' => 10, 'not_now' => -15)

    tracking.update!(prospect_stage: nil, prospect_exit: nil, last_attempt_at: 31.days.ago)
    expect(score!.prospect_score_parts).to eq('no_reply_30' => -10)
  end

  it 'pesos propios de la campaña' do
    campaign.update!(scoring: { 'weights' => { 'replied' => 35 } })
    tracking.update!(prospect_stage: 'replied')

    expect(score!.prospect_score).to eq(35)
  end

  it 'una campaña de seguimiento también puntúa (§10.12)' do
    campaign.update!(purpose: 'follow_up')
    tracking.update!(prospect_stage: 'replied')

    expect(score!.prospect_score).to eq(10)
  end

  describe TrackingCampaigns::ScoringConfig do
    it 'lo que no está guardado toma el valor sugerido; limpia lo que manda la pantalla' do
      clean = described_class.sanitize(weights: { 'replied' => '90', 'hackeo' => 5 },
                                       rules: { industry: { labels: [' Industrial ', '', 'industrial'] } })

      expect(clean['weights']).to eq('replied' => 50)
      expect(clean['rules']['industry']['labels']).to eq(['industrial'])

      campaign.update!(scoring: clean)
      expect(described_class.for(campaign)['weights']).to include('replied' => 50, 'asked_price' => 20)
    end
  end

  it 'el job recalcula toda la campaña' do
    tracking.update!(prospect_stage: 'replied')

    TrackingCampaigns::ProspectScoreJob.perform_now(campaign.id)

    expect(tracking.reload.prospect_score).to eq(10)
  end
end
