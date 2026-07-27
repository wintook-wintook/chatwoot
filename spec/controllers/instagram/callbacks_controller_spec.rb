require 'rails_helper'

RSpec.describe 'Instagram::CallbacksController', type: :request do
  let(:account) { create(:account) }
  let(:state) { 'a-random-state' }
  let(:cache_key) { format(Redis::Alfred::IG_OAUTH_STATE, state: state) }

  let(:short_lived) { { access_token: 'short-token', user_id: 17_841_400 }.with_indifferent_access }
  let(:long_lived) { { access_token: 'long-token', expires_in: 5_184_000 }.with_indifferent_access }
  let(:profile) do
    { user_id: '17841400', username: 'chatwoot', name: 'Chatwoot',
      profile_picture_url: 'https://cdn.example.com/pic.jpg' }.with_indifferent_access
  end

  let(:oauth_service) { instance_double(Instagram::OauthService) }

  before do
    allow(Instagram::OauthService).to receive(:new).and_return(oauth_service)
    allow(oauth_service).to receive(:exchange_code).and_return(short_lived)
    allow(oauth_service).to receive(:exchange_long_lived_token).and_return(long_lived)
    allow(oauth_service).to receive(:fetch_profile).and_return(profile)
    Redis::Alfred.setex(cache_key, account.id, 10.minutes)
  end

  after { Redis::Alfred.delete(cache_key) }

  describe 'GET /instagram/callback' do
    it 'stores the long lived token and the IGSID on the channel' do
      get instagram_callback_url, params: { code: 'the-code', state: state }

      channel = account.reload.instagram_channels.last
      expect(channel.instagram_id).to eq('17841400')
      expect(channel.access_token).to eq('long-token')
      expect(channel.expires_at).to be_within(1.minute).of(60.days.from_now)
      expect(channel.provider_config['username']).to eq('chatwoot')
    end

    it 'creates the inbox, fetches the avatar and sends the agent to the add agents screen' do
      expect(Avatar::AvatarFromUrlJob).to receive(:perform_later).once

      get instagram_callback_url, params: { code: 'the-code', state: state }

      inbox = account.reload.instagram_channels.last.inbox
      expect(account.inboxes.count).to be 1
      expect(inbox.name).to eq('chatwoot')
      expect(response).to redirect_to app_instagram_inbox_agents_url(account_id: account.id, inbox_id: inbox.id)
    end

    it 'consumes the state so the callback cannot be replayed' do
      get instagram_callback_url, params: { code: 'the-code', state: state }

      expect(Redis::Alfred.get(cache_key)).to be_nil
    end

    it 'redirects home and creates nothing when the state is unknown' do
      get instagram_callback_url, params: { code: 'the-code', state: 'not-a-known-state' }

      expect(account.instagram_channels.count).to be 0
      expect(response).to redirect_to '/'
    end

    it 'reports the error back to the channel screen when the user denies access' do
      get instagram_callback_url, params: { error: 'access_denied', state: state }

      expect(account.instagram_channels.count).to be 0
      expect(response).to redirect_to "#{app_new_instagram_inbox_url(account_id: account.id)}?error=denied"
    end

    it 'creates nothing when Meta rejects the code' do
      allow(oauth_service).to receive(:exchange_code).and_raise(Instagram::OauthService::OauthError, 'Invalid code')

      get instagram_callback_url, params: { code: 'bad-code', state: state }

      expect(account.instagram_channels.count).to be 0
      expect(account.inboxes.count).to be 0
      expect(response).to redirect_to "#{app_new_instagram_inbox_url(account_id: account.id)}?error=failed"
    end

    it 'rolls back the channel and the inbox if any step inside the transaction fails' do
      allow(Avatar::AvatarFromUrlJob).to receive(:perform_later).and_raise(StandardError, 'boom')

      get instagram_callback_url, params: { code: 'the-code', state: state }

      expect(account.instagram_channels.count).to be 0
      expect(account.inboxes.count).to be 0
    end
  end
end
