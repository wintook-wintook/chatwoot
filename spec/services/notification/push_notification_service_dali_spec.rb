# frozen_string_literal: true

require 'rails_helper'

# Avisos push del portal de Dali: el teléfono que los activó desde Dali abre Dali con la
# conversación; los demás abren la plataforma. Todos traen el texto del mensaje.
describe Notification::PushNotificationService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:notification) { create(:notification, user: user, account: account) }
  let(:conversation) { notification.primary_actor }
  let(:sent) { [] }

  before do
    allow(WebPush).to receive(:payload_send) { |**args| sent << JSON.parse(args[:message]) }
  end

  def subscription(dali:)
    attrs = { 'endpoint' => "https://push.example/#{SecureRandom.hex(4)}", 'p256dh' => 'x', 'auth' => 'y' }
    attrs['dali'] = true if dali
    create(:notification_subscription, user: user, subscription_attributes: attrs, identifier: attrs['endpoint'])
  end

  it 'al teléfono de Dali le manda Dali con la conversación; a los demás, la plataforma' do
    with_modified_env VAPID_PUBLIC_KEY: 'test', FRONTEND_URL: 'https://app.test' do
      subscription(dali: true)
      subscription(dali: false)
      described_class.new(notification: notification).perform
    end

    urls = sent.pluck('url')
    expect(urls).to include("https://app.test/app/accounts/#{account.id}/dali?conversation=#{conversation.display_id}")
    expect(urls.grep(%r{/conversations/#{conversation.display_id}\z}).size).to eq(1)
    expect(sent.first).to have_key('body')
  end
end
