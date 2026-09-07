require 'rails_helper'

describe Webhooks::Trigger do
  subject(:trigger) { described_class }

  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, inbox: inbox) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }

  let!(:webhook_type) { :api_inbox_webhook }
  let!(:url) { 'https://test.com' }

  # El trigger agrega instance_url al payload antes de enviarlo (ver #payload_with_instance),
  # así que lo que viaja no es el hash que recibió. Se resuelve igual que el código para que
  # el spec valga con y sin FRONTEND_URL configurada en el entorno de pruebas.
  let(:instance_url) { ENV.fetch('FRONTEND_URL', nil).presence }

  def delivered(payload)
    instance_url.present? ? payload.merge(instance_url: instance_url) : payload
  end

  describe '#execute' do
    it 'triggers webhook' do
      payload = { hello: :hello }

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: delivered(payload).to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).once
      trigger.execute(url, payload, webhook_type)
    end

    it 'updates message status if webhook fails for message-created event' do
      payload = { event: 'message_created', conversation: { id: conversation.id }, id: message.id }

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: delivered(payload).to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).once

      expect { trigger.execute(url, payload, webhook_type) }.to change { message.reload.status }.from('sent').to('failed')
    end

    it 'updates message status if webhook fails for message-updated event' do
      payload = { event: 'message_updated', conversation: { id: conversation.id }, id: message.id }

      expect(RestClient::Request).to receive(:execute)
        .with(
          method: :post,
          url: url,
          payload: delivered(payload).to_json,
          headers: { content_type: :json, accept: :json },
          timeout: 5
        ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).once
      expect { trigger.execute(url, payload, webhook_type) }.to change { message.reload.status }.from('sent').to('failed')
    end
  end

  describe 'instance url' do
    let(:payload) { { event: 'conversation_created', id: conversation.display_id } }

    around do |example|
      original = ENV.fetch('FRONTEND_URL', nil)
      example.run
      ENV['FRONTEND_URL'] = original
    end

    it 'adds the instance url to the delivered payload' do
      ENV['FRONTEND_URL'] = 'https://chat.example.com'

      expect(RestClient::Request).to receive(:execute) do |args|
        expect(JSON.parse(args[:payload])['instance_url']).to eq('https://chat.example.com')
      end

      trigger.execute(url, payload, webhook_type)
    end

    it 'omits the key when no instance url is configured' do
      ENV.delete('FRONTEND_URL')
      allow(GlobalConfigService).to receive(:load).with('FRONTEND_URL', nil).and_return(nil)

      expect(RestClient::Request).to receive(:execute) do |args|
        expect(JSON.parse(args[:payload])).not_to have_key('instance_url')
      end

      trigger.execute(url, payload, webhook_type)
    end

    it 'does not overwrite the caller payload' do
      ENV['FRONTEND_URL'] = 'https://chat.example.com'
      allow(RestClient::Request).to receive(:execute)

      trigger.execute(url, payload, webhook_type)

      expect(payload).not_to have_key(:instance_url)
    end

    # El error handler lee @payload[:event] y @payload[:id] DESPUÉS del envío: si el merge
    # mutara el hash o el rescue leyera otro, dejaría de marcar el mensaje como fallido.
    it 'still marks the message as failed after injecting the url' do
      ENV['FRONTEND_URL'] = 'https://chat.example.com'
      failing_payload = { event: 'message_created', conversation: { id: conversation.id }, id: message.id }

      allow(RestClient::Request).to receive(:execute).and_raise(RestClient::ExceptionWithResponse.new('error', 500))

      expect { trigger.execute(url, failing_payload, webhook_type) }.to change { message.reload.status }.from('sent').to('failed')
    end
  end

  it 'does not update message status if webhook fails for other events' do
    payload = { event: 'conversation_created', conversation: { id: conversation.id }, id: message.id }

    expect(RestClient::Request).to receive(:execute)
      .with(
        method: :post,
        url: url,
        payload: delivered(payload).to_json,
        headers: { content_type: :json, accept: :json },
        timeout: 5
      ).and_raise(RestClient::ExceptionWithResponse.new('error', 500)).once

    expect { trigger.execute(url, payload, webhook_type) }.not_to(change { message.reload.status })
  end
end
