require 'rails_helper'

# El payload de prueba de Meta no identifica ninguna cuenta, así que hay que decidir dónde
# aterriza. Antes iba a la última Channel::FacebookPage de TODA la instalación, que podía
# ser de otra cuenta y ni siquiera tener Instagram.
describe Instagram::TestEventService do
  let!(:account) { create(:account) }

  let(:test_messaging) do
    {
      sender: { id: '12334' },
      recipient: { id: '23245' },
      timestamp: '1527459824',
      message: { mid: 'test-mid-1', text: 'random_text' }
    }.with_indifferent_access
  end

  it 'ignores a real message' do
    real = test_messaging.merge(sender: { id: 'real-sender' })

    expect(described_class.new(real).perform).to be false
  end

  it 'does nothing when there is no instagram channel at all' do
    expect(described_class.new(test_messaging).perform).to be false
  end

  context 'when a native instagram channel exists' do
    let!(:native_channel) { create(:channel_instagram, account: account) }

    it 'materialises the test message in the instagram inbox' do
      expect(described_class.new(test_messaging).perform).to be true

      inbox = native_channel.inbox.reload
      expect(inbox.messages.count).to be 1
      expect(inbox.messages.last.content).to eq('random_text')
      expect(inbox.messages.last.message_type).to eq('incoming')
      expect(inbox.conversations.last.additional_attributes['type']).to eq('instagram_direct_message')
    end

    it 'reuses the same conversation when Meta repeats the test' do
      2.times { described_class.new(test_messaging).perform }

      expect(native_channel.inbox.reload.conversations.count).to be 1
    end

    # Lo que rompía antes: la última página de Facebook podía ser de otra cuenta
    it 'never lands on a plain messenger page from another account' do
      # Channel::FacebookPage se suscribe al webhook al crearse (comportamiento de upstream)
      stub_request(:post, %r{graph\.facebook\.com/.*/subscribed_apps})
      other_account = create(:account)
      messenger_channel = create(:channel_facebook_page, account: other_account)
      messenger_inbox = create(:inbox, channel: messenger_channel, account: other_account)

      described_class.new(test_messaging).perform

      expect(messenger_inbox.reload.messages.count).to be 0
      expect(native_channel.inbox.reload.messages.count).to be 1
    end
  end

  # Sin canal nativo todavía, la prueba se atiende por la ruta legacy
  context 'when only a legacy instagram-capable page exists' do
    it 'falls back to the facebook page that carries instagram' do
      legacy_channel = create(:channel_instagram_fb_page, account: account, instagram_id: 'ig-legacy')
      legacy_inbox = create(:inbox, channel: legacy_channel, account: account, greeting_enabled: false)

      expect(described_class.new(test_messaging).perform).to be true
      expect(legacy_inbox.reload.messages.count).to be 1
    end
  end
end
