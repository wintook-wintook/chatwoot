# frozen_string_literal: true

require 'rails_helper'

# prospeccion V6 (docs/prospeccion_estudio.md §8.1, §10.1) — el embudo de una campaña de prospección.
RSpec.describe TrackingCampaigns::ProspectingFunnel do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox, purpose: 'prospecting', daily_cap: 30) }

  def prospect(attrs = {})
    create(:contact_tracking, { account: account, inbox: inbox, tracking_campaign: campaign,
                                contact: create(:contact, account: account) }.merge(attrs))
  end

  it 'cuenta etapas y salidas' do
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
      not_now: 1, not_interested: 1, wrong_person: 0, opted_out: 1, no_reply: 1
    )
  end
end
