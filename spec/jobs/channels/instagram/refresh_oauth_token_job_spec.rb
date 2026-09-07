require 'rails_helper'

RSpec.describe Channels::Instagram::RefreshOauthTokenJob do
  subject(:job) { described_class }

  let!(:account) { create(:account) }
  let(:oauth_service) { instance_double(Instagram::OauthService) }

  before do
    allow(Instagram::OauthService).to receive(:new).and_return(oauth_service)
  end

  context 'when the token can be refreshed' do
    let!(:channel) do
      create(:channel_instagram, account: account, access_token: 'old-token', expires_at: 5.days.from_now)
    end

    before do
      allow(oauth_service).to receive(:refresh_long_lived_token)
        .and_return({ access_token: 'brand-new-token', expires_in: 5_184_000 }.with_indifferent_access)
    end

    it 'stores the new token and pushes the expiry 60 days out' do
      job.perform_now(channel)

      channel.reload
      expect(channel.access_token).to eq('brand-new-token')
      expect(channel.expires_at).to be_within(1.minute).of(60.days.from_now)
    end

    it 'clears a pending reauthorization flag' do
      channel.prompt_reauthorization!
      expect(channel.reauthorization_required?).to be true

      job.perform_now(channel)

      expect(channel.reauthorization_required?).to be false
    end

    it 'keeps the previous expiry when Meta does not report a lifetime' do
      allow(oauth_service).to receive(:refresh_long_lived_token)
        .and_return({ access_token: 'brand-new-token' }.with_indifferent_access)
      previous_expiry = channel.expires_at

      job.perform_now(channel)

      expect(channel.reload.expires_at).to be_within(1.second).of(previous_expiry)
    end
  end

  context 'when Meta rejects the refresh' do
    let!(:channel) do
      create(:channel_instagram, account: account, access_token: 'old-token', expires_at: 5.days.from_now)
    end

    before do
      allow(oauth_service).to receive(:refresh_long_lived_token)
        .and_raise(Instagram::OauthService::OauthError, 'Invalid OAuth access token')
    end

    it 'asks for reauthorization instead of failing the job' do
      expect { job.perform_now(channel) }.not_to raise_error

      expect(channel.reauthorization_required?).to be true
    end

    it 'keeps the old token so nothing is lost' do
      job.perform_now(channel)

      expect(channel.reload.access_token).to eq('old-token')
    end
  end

  context 'when the token has already expired' do
    let!(:channel) do
      create(:channel_instagram, account: account, access_token: 'dead-token', expires_at: 1.day.ago)
    end

    it 'does not waste a call on a token Meta cannot renew' do
      expect(oauth_service).not_to receive(:refresh_long_lived_token)

      job.perform_now(channel)

      expect(channel.reauthorization_required?).to be true
    end
  end
end
