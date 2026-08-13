require 'rails_helper'

describe Instagram::ReadStatusService do
  before do
    create(:message, message_type: :incoming, inbox: instagram_inbox, account: account, conversation: conversation,
                     source_id: 'chatwoot-app-user-id-1')
  end

  let!(:account) { create(:account) }
  let!(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'chatwoot-app-user-id-1') }
  let!(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account, greeting_enabled: false) }
  let!(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox) }
  let(:conversation) { create(:conversation, contact: contact, inbox: instagram_inbox, contact_inbox: contact_inbox) }

  describe '#perform' do
    context 'when messaging_seen callback is fired' do
      let(:message) { conversation.messages.last }

      before do
        allow(Conversations::UpdateMessageStatusJob).to receive(:perform_later)
      end

      it 'enqueues the UpdateMessageStatusJob with correct parameters if the message is found' do
        params = {
          recipient: {
            id: 'chatwoot-app-user-id-1'
          },
          read: {
            mid: message.source_id
          }
        }
        described_class.new(params: params).perform
        expect(Conversations::UpdateMessageStatusJob).to have_received(:perform_later).with(conversation.id, message.created_at)
      end

      it 'does not enqueue the UpdateMessageStatusJob if the message is not found' do
        params = {
          recipient: {
            id: 'chatwoot-app-user-id-1'
          },
          read: {
            mid: 'random-message-id'
          }
        }
        described_class.new(params: params).perform
        expect(Conversations::UpdateMessageStatusJob).not_to have_received(:perform_later)
      end
    end

    # Router dual: el canal nativo manda sobre el legacy para el mismo IGSID
    context 'when the account is served by the native channel' do
      let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: 'native-ig-account') }
      let(:native_contact_inbox) { create(:contact_inbox, contact: contact, inbox: native_channel.inbox, source_id: 'ig-contact') }
      let(:native_conversation) do
        create(:conversation, contact: contact, inbox: native_channel.inbox, contact_inbox: native_contact_inbox)
      end
      let!(:native_message) do
        create(:message, message_type: :outgoing, inbox: native_channel.inbox, account: account,
                         conversation: native_conversation, source_id: 'mid.native')
      end

      before { allow(Conversations::UpdateMessageStatusJob).to receive(:perform_later) }

      it 'resolves the native channel and marks the message as read' do
        params = { recipient: { id: 'native-ig-account' }, read: { mid: 'mid.native' } }

        described_class.new(params: params).perform

        # created_at recargado: en memoria tiene nanosegundos, en la BD solo microsegundos
        expect(Conversations::UpdateMessageStatusJob)
          .to have_received(:perform_later).with(native_conversation.id, native_message.reload.created_at)
      end

      it 'ignores events for an instagram account nobody has connected' do
        params = { recipient: { id: 'unknown-ig-account' }, read: { mid: 'mid.native' } }

        expect { described_class.new(params: params).perform }.not_to raise_error
        expect(Conversations::UpdateMessageStatusJob).not_to have_received(:perform_later)
      end
    end
  end
end
