# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F0: la campaña con ventana y sus inscripciones
# (docs/automatizacion_campanas_plan.md §5).
RSpec.describe TrackingCampaign do
  let(:campaign) { create(:tracking_campaign, scheduled_for: 1.day.from_now) }

  describe 'la ventana' do
    it 'las campañas nacen por lote, sin fin, sin espera y respetando el horario' do
      expect(campaign).to have_attributes(mode: 'batch', ends_at: nil, entry_delay_minutes: 0,
                                          respect_working_hours: true, daily_cap: nil, audience: {})
      expect(campaign).not_to be_continuous
    end

    it 'el fin tiene que ser posterior al inicio' do
      campaign.ends_at = campaign.scheduled_for - 1.hour

      expect(campaign).not_to be_valid
      expect(campaign.errors[:ends_at]).to be_present
    end

    it 'valida el tipo, la espera y el tope diario' do
      expect(build(:tracking_campaign, mode: 'otro')).not_to be_valid
      expect(build(:tracking_campaign, entry_delay_minutes: -1)).not_to be_valid
      expect(build(:tracking_campaign, daily_cap: 0)).not_to be_valid
      expect(build(:tracking_campaign, mode: 'continuous', daily_cap: 200)).to be_valid
    end

    it 'acepta inscripciones antes del inicio y durante; no pausada, terminada ni pasado el fin' do
      campaign.update!(status: 'draft', ends_at: 10.days.from_now)
      expect(campaign.accepting_entries?).to be(true)
      expect(campaign.accepting_entries?(11.days.from_now)).to be(false)

      %w[paused finished].each do |status|
        campaign.status = status
        expect(campaign.accepting_entries?).to be(false)
      end
    end
  end

  describe 'las inscripciones' do
    let(:contact) { create(:contact, account: campaign.account) }

    it 'un contacto se inscribe una sola vez; los omitidos se repiten' do
      create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact)

      expect { create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact) }
        .to raise_error(ActiveRecord::RecordNotUnique)
      2.times do
        create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact, status: 'skipped',
                                         reason: 'already_enrolled', source: 'automation')
      end
      expect(campaign.entries.enrolled.count).to eq(1)
      expect(campaign.entries.skipped.count).to eq(2)
    end

    it 'un omitido lleva su motivo y un inscrito no' do
      expect(build(:tracking_campaign_entry, tracking_campaign: campaign, status: 'skipped')).not_to be_valid
      expect(build(:tracking_campaign_entry, tracking_campaign: campaign, reason: 'daily_cap')).not_to be_valid
      expect(build(:tracking_campaign_entry, tracking_campaign: campaign, source: 'manual')).not_to be_valid
    end

    it 'borrar la conversación o la automatización no borra la inscripción; borrar el contacto sí' do
      conversation = create(:conversation, account: campaign.account, contact: contact)
      rule = create(:automation_rule, account: campaign.account)
      entry = create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact, source: 'automation',
                                               conversation: conversation, automation_rule: rule)

      conversation.destroy!
      rule.destroy!
      expect(entry.reload).to have_attributes(conversation_id: nil, automation_rule_id: nil)

      contact.destroy!
      expect(TrackingCampaignEntry.exists?(entry.id)).to be(false)
    end

    it 'borrar la campaña borra sus inscripciones' do
      entry = create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact)

      campaign.destroy!
      expect(TrackingCampaignEntry.exists?(entry.id)).to be(false)
    end
  end
end
