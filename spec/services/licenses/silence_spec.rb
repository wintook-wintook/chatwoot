# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F3) — una cuenta suspendida no habla sola
RSpec.describe Licenses::Silence do
  let(:account) { create(:account) }

  it 'solo calla a una cuenta suspendida' do
    expect(described_class.silenced?(account)).to be(false)
    account.update!(status: :suspended)
    expect(described_class.silenced?(account)).to be(true)
    expect(described_class.silenced?(nil)).to be(false)
  end

  describe 'campañas' do
    let(:inbox) { create(:inbox, account: account) }

    it 'el despachador no toma seguimientos de una cuenta suspendida' do
      tracking = create(:contact_tracking, account: account, inbox: inbox, contact: create(:contact, account: account))
      tracking.update_columns(scheduled_for: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
      allow(TrackingDispatch::MessagingTier).to receive(:daily_limit).and_return(nil)
      account.update!(status: :suspended)

      ids = with_modified_env('TRACKING_DISPATCHER_ACCOUNTS' => account.id.to_s) { TrackingDispatch::Claim.new.call }.map(&:first)

      expect(ids).not_to include(tracking.id)
    end
  end

  describe 'primer mensaje de un seguimiento' do
    include ActiveJob::TestHelper

    it 'no lo da por fallido: se reprograma' do
      tracking = create(:contact_tracking, account: account, inbox: create(:inbox, account: account),
                                           contact: create(:contact, account: account))
      account.update!(status: :suspended)

      expect { ContactTrackingJob.perform_now(tracking.id) }.to have_enqueued_job(ContactTrackingJob).with(tracking.id)
      expect(tracking.reload.status).not_to eq('failed')
    end
  end
end
