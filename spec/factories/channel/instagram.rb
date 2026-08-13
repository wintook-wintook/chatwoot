# frozen_string_literal: true

# Canal nativo de Instagram. Ojo: `channel_instagram_fb_page` (en instagram_channel.rb)
# es la ruta legacy — un Channel::FacebookPage — y no tiene nada que ver con esta.
FactoryBot.define do
  factory :channel_instagram, class: 'Channel::Instagram' do
    access_token { SecureRandom.uuid }
    instagram_id { SecureRandom.uuid }
    expires_at { 60.days.from_now }
    provider_config { { username: 'chatwoot_test' } }
    account

    after(:create) do |channel_instagram|
      create(:inbox, channel: channel_instagram, account: channel_instagram.account)
    end
  end
end
