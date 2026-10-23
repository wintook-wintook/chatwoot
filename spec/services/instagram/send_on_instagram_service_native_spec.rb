require 'rails_helper'

# El mismo servicio sirve a las dos rutas. Aquí se comprueba lo que cambia entre ellas:
# el host y la credencial. Ver docs/instagram_plan.md §6 F4
describe Instagram::SendOnInstagramService do
  let!(:account) { create(:account) }
  let!(:contact) { create(:contact, account: account) }

  describe 'native channel' do
    let!(:channel) { create(:channel_instagram, account: account, instagram_id: 'ig-business-id', access_token: 'native-token') }
    let(:inbox) { channel.inbox }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'ig-contact-id') }
    let(:conversation) do
      create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox,
                            additional_attributes: { type: 'instagram_direct_message' })
    end

    before do
      create(:message, message_type: :incoming, inbox: inbox, account: account, conversation: conversation)
    end

    it 'posts to graph.instagram.com with the channel token and never touches graph.facebook.com' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub = stub_request(:post, %r{graph\.instagram\.com/.*/ig-business-id/messages})
             .with(query: hash_including({ 'access_token' => 'native-token' }))
             .to_return(status: 200, body: { message_id: 'mid.native' }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(stub).to have_been_requested
      expect(message.reload.source_id).to eq('mid.native')
      expect(WebMock).not_to have_requested(:post, /graph\.facebook\.com/)
    end

    it 'marks the message as failed when Meta rejects it' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub_request(:post, %r{graph\.instagram\.com/.*/messages})
        .to_return(status: 400, body: { error: { message: 'Message failed to send', code: 10 } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq('10 - Message failed to send')
    end

    # Sin esto el canal se queda enviando a la nada: los mensajes fallan uno a uno y el
    # administrador no ve el aviso de reautorizar en ningún sitio.
    it 'marks the channel for reauthorization when the token died (190)' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub_request(:post, %r{graph\.instagram\.com/.*/messages})
        .to_return(status: 400, body: { error: { message: 'Invalid OAuth access token', code: 190 } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(message.reload.status).to eq('failed')
      expect(channel.reload.authorization_error_count).to be_positive
    end

    it 'leaves the authorization alone for an ordinary send failure' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub_request(:post, %r{graph\.instagram\.com/.*/messages})
        .to_return(status: 400, body: { error: { message: 'Message failed to send', code: 10 } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(channel.reload.authorization_error_count).to be 0
    end

    it 'sends attachments through the native host too' do
      message = build(:message, content: nil, message_type: 'outgoing', inbox: inbox, account: account, conversation: conversation)
      attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
      attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      message.save!

      stub = stub_request(:post, %r{graph\.instagram\.com/.*/messages})
             .to_return(status: 200, body: { message_id: 'mid.attachment' }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(stub).to have_been_requested
    end
  end

  # Los specs previos stubean HTTParty.post devolviendo un hash con claves símbolo, que no
  # es lo que produce una respuesta real. Con el JSON de verdad (claves string) el error de
  # Meta se perdía y el mensaje se quedaba en «enviado».
  describe 'legacy channel with a realistic HTTP response' do
    let!(:channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'legacy-ig-id') }
    let!(:inbox) { create(:inbox, channel: channel, account: account, greeting_enabled: false) }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'ig-contact-id') }
    let(:conversation) do
      create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox,
                            additional_attributes: { type: 'instagram_direct_message' })
    end

    before do
      stub_request(:post, %r{graph\.facebook\.com/.*/subscribed_apps})
      # En test FB_APP_SECRET llega vacío desde .env, y sin secreto el cálculo del
      # appsecret_proof revienta: el rescue del servicio se lo traga y el POST no sale.
      allow(Facebook::Messenger::Configuration::AppSecretProofCalculator).to receive(:call).and_return('app_secret_proof')
      create(:message, message_type: :incoming, inbox: inbox, account: account, conversation: conversation)
    end

    it 'still posts to graph.facebook.com with the page token' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub = stub_request(:post, %r{graph\.facebook\.com/.*/me/messages})
             .to_return(status: 200, body: { message_id: 'mid.legacy' }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(stub).to have_been_requested
      expect(message.reload.source_id).to eq('mid.legacy')
    end

    it 'marks the message as failed when Meta rejects it' do
      message = create(:message, message_type: 'outgoing', content: 'hola', inbox: inbox, account: account, conversation: conversation)

      stub_request(:post, %r{graph\.facebook\.com/.*/me/messages})
        .to_return(status: 400, body: { error: { message: 'Outside allowed window', code: 10 } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.new(message: message).perform

      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq('10 - Outside allowed window')
    end
  end

  describe 'channel validation' do
    it 'refuses to run on a channel it does not serve' do
      whatsapp_channel = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
      inbox = create(:inbox, channel: whatsapp_channel, account: account)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
      conversation = create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox)
      message = create(:message, message_type: 'outgoing', inbox: inbox, account: account, conversation: conversation)

      expect { described_class.new(message: message).perform }.to raise_error('Invalid channel service was called')
    end
  end

  describe SendReplyJob do
    it 'routes a native instagram message to the instagram service' do
      channel = create(:channel_instagram, account: account, instagram_id: 'ig-business-id')
      inbox = channel.inbox
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'ig-contact-id')
      conversation = create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox)
      message = create(:message, message_type: 'outgoing', inbox: inbox, account: account, conversation: conversation)

      service = double
      allow(Instagram::SendOnInstagramService).to receive(:new).with(message: message).and_return(service)
      allow(service).to receive(:perform)

      described_class.perform_now(message.id)

      expect(service).to have_received(:perform)
    end
  end
end
