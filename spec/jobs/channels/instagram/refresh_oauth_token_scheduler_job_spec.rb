require 'rails_helper'

RSpec.describe Channels::Instagram::RefreshOauthTokenSchedulerJob do
  subject(:job) { described_class }

  let!(:account) { create(:account) }

  it 'enqueues a refresh for tokens inside the safety margin' do
    expiring = create(:channel_instagram, account: account, expires_at: 3.days.from_now)

    expect { job.perform_now }.to have_enqueued_job(Channels::Instagram::RefreshOauthTokenJob).with(expiring)
  end

  it 'leaves healthy tokens alone' do
    healthy = create(:channel_instagram, account: account, expires_at: 59.days.from_now)

    # La aserción nombra el canal: así no depende de que no exista ninguna otra fila
    expect { job.perform_now }.not_to have_enqueued_job(Channels::Instagram::RefreshOauthTokenJob).with(healthy)
  end

  it 'still picks up tokens that already expired, so the admin gets told' do
    expired = create(:channel_instagram, account: account, expires_at: 2.days.ago)

    expect { job.perform_now }.to have_enqueued_job(Channels::Instagram::RefreshOauthTokenJob).with(expired)
  end

  it 'picks up channels with no known expiry instead of letting them die silently' do
    unknown = create(:channel_instagram, account: account, expires_at: nil)

    expect { job.perform_now }.to have_enqueued_job(Channels::Instagram::RefreshOauthTokenJob).with(unknown)
  end

  it 'does not touch legacy instagram channels, which have no token of their own' do
    legacy = create(:channel_instagram_fb_page, account: account, instagram_id: 'legacy-ig')

    expect { job.perform_now }.not_to have_enqueued_job(Channels::Instagram::RefreshOauthTokenJob).with(legacy)
  end
end
