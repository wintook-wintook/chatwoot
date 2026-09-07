require 'rails_helper'

describe BotSeller::Dispatcher do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, content: 'hola') }

  let(:webhook_url) { 'https://botseller.example.com/hook?token=old' }
  let(:sent) { {} }

  # El endpoint sale de INTERNAL_WEBHOOK_URL y la instancia de FRONTEND_URL: las dos se
  # restauran para no filtrar el valor a otros ejemplos.
  around do |example|
    original_internal = ENV.fetch('INTERNAL_WEBHOOK_URL', nil)
    original_frontend = ENV.fetch('FRONTEND_URL', nil)
    ENV['INTERNAL_WEBHOOK_URL'] = webhook_url
    example.run
    ENV['INTERNAL_WEBHOOK_URL'] = original_internal
    ENV['FRONTEND_URL'] = original_frontend
  end

  # El cuerpo se captura en el propio stub: es lo que realmente viajó.
  def stub_botseller
    stub_request(:post, /botseller.example.com/).to_return do |request|
      sent.merge!(JSON.parse(request.body))
      { status: 200, body: '' }
    end
  end

  describe '#dispatch' do
    it 'sends the instance url alongside the event' do
      ENV['FRONTEND_URL'] = 'https://chat.example.com'
      stub_botseller

      described_class.new(message).dispatch

      expect(sent['instance_url']).to eq('https://chat.example.com')
      expect(sent['event']).to eq('message_created')
    end

    it 'omits the key when no instance url is configured' do
      ENV.delete('FRONTEND_URL')
      allow(GlobalConfigService).to receive(:load).with('FRONTEND_URL', nil).and_return(nil)
      stub_botseller

      described_class.new(message).dispatch

      expect(sent).not_to have_key('instance_url')
      expect(sent['event']).to eq('message_created')
    end

    it 'still sends the message payload it always sent' do
      ENV['FRONTEND_URL'] = 'https://chat.example.com'
      stub_botseller

      described_class.new(message).dispatch

      expect(sent['id']).to eq(message.id)
      expect(sent['content']).to eq('hola')
      expect(sent.dig('account', 'id')).to eq(account.id)
    end

    it 'does not raise when the endpoint fails' do
      stub_request(:post, /botseller.example.com/).to_timeout

      expect { described_class.new(message).dispatch }.not_to raise_error
    end

    it 'does nothing without INTERNAL_WEBHOOK_URL' do
      ENV.delete('INTERNAL_WEBHOOK_URL')

      described_class.new(message).dispatch

      expect(a_request(:post, /botseller.example.com/)).not_to have_been_made
    end
  end
end
