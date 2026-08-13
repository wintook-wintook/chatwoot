require 'rails_helper'

# Router dual y idempotencia: lo que permite que una cuenta entregue por la ruta legacy
# y por la nativa a la vez durante la migración. Ver docs/instagram_plan.md §5 y §5.1
describe Webhooks::InstagramEventsJob do
  subject(:instagram_webhook) { described_class }

  let!(:account) { create(:account) }
  let(:ig_account_id) { 'chatwoot-app-user-id-1' }
  let!(:dm_params) { build(:instagram_message_create_event).with_indifferent_access }

  let(:contact_profile) do
    { 'id' => 'Sender-id-1', 'name' => 'Jane', 'username' => 'some_user_name',
      'profile_pic' => 'https://chatwoot-assets.local/sample.png' }
  end

  before do
    stub_request(:post, /graph.facebook.com/)
    stub_request(:get, 'https://www.example.com/test.jpeg').to_return(status: 200, body: '', headers: {})
    stub_request(:get, 'https://chatwoot-assets.local/sample.png').to_return(status: 200, body: '', headers: {})
  end

  describe 'routing to the native channel' do
    let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: ig_account_id) }
    let(:native_inbox) { native_channel.inbox }

    before do
      allow_any_instance_of(Channel::Instagram).to receive(:fetch_contact_profile).and_return(contact_profile) # rubocop:disable RSpec/AnyInstance
    end

    it 'creates the message in the native inbox' do
      instagram_webhook.perform_now(dm_params[:entry])

      native_inbox.reload
      expect(native_inbox.messages.count).to be 1
      expect(native_inbox.messages.last.content).to eq 'This is the first message from the customer'
      expect(native_inbox.contacts.last.additional_attributes['social_instagram_user_name']).to eq 'some_user_name'
    end

    it 'marks the conversation as an instagram direct message so the 24h window still applies' do
      instagram_webhook.perform_now(dm_params[:entry])

      conversation = native_inbox.reload.conversations.last
      expect(conversation.additional_attributes['type']).to eq 'instagram_direct_message'
    end

    it 'fetches the contact profile through the channel token, not through Koala' do
      expect(Koala::Facebook::API).not_to receive(:new)

      instagram_webhook.perform_now(dm_params[:entry])

      expect(native_inbox.reload.contacts.count).to be 1
    end
  end

  describe 'when the same IGSID exists on both channels' do
    let!(:legacy_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: ig_account_id) }
    let!(:legacy_inbox) { create(:inbox, channel: legacy_channel, account: account, greeting_enabled: false) }
    let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: ig_account_id) }

    before do
      allow_any_instance_of(Channel::Instagram).to receive(:fetch_contact_profile).and_return(contact_profile) # rubocop:disable RSpec/AnyInstance
    end

    it 'gives priority to the native channel and leaves the legacy inbox untouched' do
      instagram_webhook.perform_now(dm_params[:entry])

      expect(native_channel.inbox.reload.messages.count).to be 1
      expect(legacy_inbox.reload.messages.count).to be 0
    end
  end

  describe 'idempotency' do
    let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: ig_account_id) }

    before do
      allow_any_instance_of(Channel::Instagram).to receive(:fetch_contact_profile).and_return(contact_profile) # rubocop:disable RSpec/AnyInstance
    end

    it 'does not duplicate the message when the same event is delivered twice' do
      2.times { instagram_webhook.perform_now(dm_params[:entry]) }

      expect(native_channel.inbox.reload.messages.count).to be 1
      expect(native_channel.inbox.conversations.count).to be 1
    end

    # El descarte por contenido vacío tiene que ir antes que el de idempotencia: resolver
    # la conversación para comprobar el `mid` la crearía, dejando conversaciones huérfanas.
    it 'does not create an empty conversation for a message that never materialises' do
      unsupported = build(:instagram_message_unsupported_event).with_indifferent_access
      unsupported[:entry][0][:messaging][0][:message][:text] = nil
      unsupported[:entry][0][:messaging][0][:message][:attachments] = [{ type: 'unsupported_type', payload: { url: '' } }]

      instagram_webhook.perform_now(unsupported[:entry])

      expect(native_channel.inbox.reload.messages.count).to be 0
      expect(native_channel.inbox.conversations.count).to be 0
    end
  end

  describe 'idempotency on the legacy route' do
    let!(:legacy_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: ig_account_id) }
    let!(:legacy_inbox) { create(:inbox, channel: legacy_channel, account: account, greeting_enabled: false) }
    let(:fb_object) { double }

    before do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return(contact_profile.with_indifferent_access)
    end

    it 'does not duplicate the message when Meta retries the webhook' do
      2.times { instagram_webhook.perform_now(dm_params[:entry]) }

      expect(legacy_inbox.reload.messages.count).to be 1
    end
  end

  # No todo fallo al leer el perfil es una avería del canal: tratarlos igual marcaba la
  # autorización como rota por errores normales y tiraba mensajes que sí se podían guardar.
  describe 'error codes from Meta while fetching the contact profile' do
    let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: ig_account_id) }

    def fail_profile_with(code, message = 'boom')
      allow_any_instance_of(Channel::Instagram).to receive(:fetch_contact_profile) # rubocop:disable RSpec/AnyInstance
        .and_raise(Instagram::OauthService::OauthError.new(message, code))
    end

    it 'marks the channel for reauthorization on 190 (token expired)' do
      fail_profile_with(190, 'Invalid OAuth access token')

      instagram_webhook.perform_now(dm_params[:entry])

      expect(native_channel.reload.authorization_error_count).to be_positive
    end

    # El usuario nunca escribió primero: Meta no da su perfil y es lo esperado
    it 'does not touch the authorization on 230 (consent required)' do
      fail_profile_with(230, 'User consent is required')

      instagram_webhook.perform_now(dm_params[:entry])

      expect(native_channel.reload.authorization_error_count).to be 0
    end

    # Es el bot con el que Meta valida la app en App Review: si no se crea contacto, la
    # revisión no ve ningún mensaje y rechaza la integración.
    it 'creates a generic contact on 9010 so App Review sees the message arrive' do
      fail_profile_with(9010, 'No matching Instagram user')

      instagram_webhook.perform_now(dm_params[:entry])

      inbox = native_channel.inbox.reload
      expect(inbox.messages.count).to be 1
      expect(inbox.contacts.last.name).to include('Instagram')
      expect(native_channel.reload.authorization_error_count).to be 0
    end

    it 'reports an unexpected code without marking the channel' do
      fail_profile_with(1, 'Unknown error')

      instagram_webhook.perform_now(dm_params[:entry])

      expect(native_channel.reload.authorization_error_count).to be 0
    end
  end

  describe 'read status' do
    let(:messaging_seen_event) { build(:messaging_seen_event).with_indifferent_access }

    before do
      create(:channel_instagram, account: account, instagram_id: ig_account_id)
      allow_any_instance_of(Channel::Instagram).to receive(:fetch_contact_profile).and_return(contact_profile) # rubocop:disable RSpec/AnyInstance
    end

    it 'resolves the native channel for seen events' do
      instagram_webhook.perform_now(dm_params[:entry])
      expect { instagram_webhook.perform_now(messaging_seen_event[:entry]) }.not_to raise_error
    end
  end
end
