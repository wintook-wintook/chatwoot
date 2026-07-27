# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join 'spec/models/concerns/reauthorizable_shared.rb'

RSpec.describe Channel::Instagram do
  let!(:channel) { create(:channel_instagram) }

  describe 'concerns' do
    it_behaves_like 'reauthorizable'

    context 'when prompt_reauthorization!' do
      it 'calls channel notifier mail for instagram' do
        admin_mailer = double
        mailer_double = double

        expect(AdministratorNotifications::ChannelNotificationsMailer).to receive(:with).and_return(admin_mailer)
        expect(admin_mailer).to receive(:instagram_disconnect).with(channel.inbox).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_later)

        channel.prompt_reauthorization!
      end
    end
  end

  describe 'validations' do
    it 'requires an access_token' do
      channel.access_token = nil
      expect(channel).not_to be_valid
    end

    it 'does not allow the same instagram_id twice' do
      duplicate = build(:channel_instagram, instagram_id: channel.instagram_id)
      expect(duplicate).not_to be_valid
    end
  end

  describe '#name' do
    it 'returns Instagram' do
      expect(channel.name).to eq('Instagram')
    end
  end

  describe '#messaging_window_enabled?' do
    it 'is enabled' do
      expect(channel.messaging_window_enabled?).to be(true)
    end
  end

  describe 'token expiry' do
    it 'is not expired with a token valid for 60 days' do
      expect(channel.token_expired?).to be(false)
      expect(channel.token_about_to_expire?).to be(false)
    end

    it 'is expired once expires_at is in the past' do
      channel.expires_at = 1.hour.ago
      expect(channel.token_expired?).to be(true)
    end

    it 'is about to expire inside the refresh threshold' do
      channel.expires_at = 5.days.from_now
      expect(channel.token_about_to_expire?).to be(true)
      expect(channel.token_expired?).to be(false)
    end
  end

  describe '#fetch_contact_profile' do
    it 'returns the profile with the same keys Koala returns, so the legacy path keeps working' do
      stub_request(:get, %r{graph\.instagram\.com/.*/ig-scoped-id})
        .to_return(status: 200,
                   body: { name: 'Jane', username: 'jane_ig', profile_pic: 'https://cdn/jane.jpg' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      profile = channel.fetch_contact_profile('ig-scoped-id')

      expect(profile['id']).to eq('ig-scoped-id')
      expect(profile['name']).to eq('Jane')
      expect(profile['username']).to eq('jane_ig')
    end

    it 'raises OauthError when the token is no longer valid' do
      stub_request(:get, %r{graph\.instagram\.com/.*/ig-scoped-id})
        .to_return(status: 401, body: { error: { message: 'Invalid OAuth access token' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { channel.fetch_contact_profile('ig-scoped-id') }
        .to raise_error(Instagram::OauthService::OauthError, /Invalid OAuth access token/)
    end
  end

  describe '#create_contact_inbox' do
    it 'creates the contact inbox with the IGSID as source_id' do
      contact_inbox = channel.create_contact_inbox('ig-scoped-id', 'Jane')

      expect(contact_inbox.source_id).to eq('ig-scoped-id')
      expect(contact_inbox.contact.name).to eq('Jane')
      expect(contact_inbox.inbox).to eq(channel.inbox)
    end
  end
end
