# frozen_string_literal: true

require 'rails_helper'

# fix/campanas (punto 2): pausar la campaña a mano calla al Agente IA en sus conversaciones.
RSpec.describe TrackingCampaign, '.silences_conversation?' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:campaign) { create(:tracking_campaign, account: account, status: 'paused') }

  def tracking(status: 'active', campaign: self.campaign)
    create(:contact_tracking, account: account, inbox: inbox, contact: conversation.contact,
                              conversation: conversation, tracking_campaign: campaign, status: status)
  end

  it 'is true with a live tracking of a campaign paused by hand' do
    tracking
    expect(described_class.silences_conversation?(conversation.id)).to be(true)
  end

  it 'also counts trackings the campaign already paused' do
    tracking(status: 'paused')
    expect(described_class.silences_conversation?(conversation.id)).to be(true)
  end

  it 'is false when the campaign is running' do
    campaign.update_columns(status: 'running') # rubocop:disable Rails/SkipsModelValidations
    tracking
    expect(described_class.silences_conversation?(conversation.id)).to be(false)
  end

  it 'is false when Meta paused it (paused_reason)' do
    campaign.update_columns(paused_reason: 'Cuenta bloqueada') # rubocop:disable Rails/SkipsModelValidations
    tracking
    expect(described_class.silences_conversation?(conversation.id)).to be(false)
  end

  it 'is false when the tracking already ended' do
    tracking(status: 'completed')
    expect(described_class.silences_conversation?(conversation.id)).to be(false)
  end

  it 'is false for a tracking without campaign' do
    tracking(campaign: nil)
    expect(described_class.silences_conversation?(conversation.id)).to be(false)
  end
end
