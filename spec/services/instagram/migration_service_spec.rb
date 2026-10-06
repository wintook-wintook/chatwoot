require 'rails_helper'

RSpec.describe Instagram::MigrationService do
  let!(:account) { create(:account) }
  let(:igsid) { 'shared-ig-account-id' }

  let!(:legacy_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: igsid) }
  let!(:legacy_inbox) { create(:inbox, channel: legacy_channel, account: account) }
  let!(:native_channel) { create(:channel_instagram, account: account, instagram_id: igsid) }
  let(:native_inbox) { native_channel.inbox }

  # Una conversación de Instagram y otra de Messenger conviviendo en el inbox legacy,
  # que es exactamente la situación que hay que desenredar.
  let(:ig_contact) { create(:contact, account: account) }
  let(:ig_contact_inbox) { create(:contact_inbox, contact: ig_contact, inbox: legacy_inbox, source_id: 'ig-contact-igsid') }
  let!(:ig_conversation) do
    create(:conversation, account: account, inbox: legacy_inbox, contact: ig_contact, contact_inbox: ig_contact_inbox,
                          additional_attributes: { type: 'instagram_direct_message' })
  end

  let(:fb_contact) { create(:contact, account: account) }
  let(:fb_contact_inbox) { create(:contact_inbox, contact: fb_contact, inbox: legacy_inbox, source_id: 'messenger-psid') }
  let!(:fb_conversation) do
    create(:conversation, account: account, inbox: legacy_inbox, contact: fb_contact, contact_inbox: fb_contact_inbox)
  end

  before do
    stub_request(:post, %r{graph\.facebook\.com/.*/subscribed_apps})
    create(:message, account: account, inbox: legacy_inbox, conversation: ig_conversation, content: 'hola por IG')
    create(:message, account: account, inbox: legacy_inbox, conversation: fb_conversation, content: 'hola por Messenger')
  end

  describe 'dry run' do
    it 'reports what would move without touching anything' do
      report = described_class.new(legacy_inbox: legacy_inbox, native_inbox: native_inbox).perform

      expect(report[:conversations]).to eq(1)
      expect(report[:messages]).to eq(1)
      expect(report[:messenger_conversations_left_behind]).to eq(1)
      expect(report[:applied]).to be false

      expect(ig_conversation.reload.inbox_id).to eq(legacy_inbox.id)
      expect(legacy_channel.reload.instagram_id).to eq(igsid)
    end
  end

  describe 'apply' do
    subject(:migrate) { described_class.new(legacy_inbox: legacy_inbox, native_inbox: native_inbox, apply: true).perform }

    it 'moves the instagram conversation and its messages' do
      migrate

      expect(ig_conversation.reload.inbox_id).to eq(native_inbox.id)
      expect(ig_conversation.messages.pluck(:inbox_id).uniq).to eq([native_inbox.id])
    end

    it 'moves the instagram contact inbox keeping its source id' do
      migrate

      ig_contact_inbox.reload
      expect(ig_contact_inbox.inbox_id).to eq(native_inbox.id)
      expect(ig_contact_inbox.source_id).to eq('ig-contact-igsid')
    end

    it 'leaves the messenger conversation exactly where it was' do
      migrate

      expect(fb_conversation.reload.inbox_id).to eq(legacy_inbox.id)
      expect(fb_contact_inbox.reload.inbox_id).to eq(legacy_inbox.id)
      expect(fb_conversation.messages.pluck(:inbox_id).uniq).to eq([legacy_inbox.id])
    end

    # Sin esto los agentes perderían el acceso: el inbox nativo nace sin miembros
    it 'copies the agents over so nobody loses access' do
      agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: legacy_inbox, user: agent)

      migrate

      expect(native_inbox.reload.members).to include(agent)
      expect(legacy_inbox.reload.members).to include(agent)
    end

    it 'does not duplicate an agent already present in the native inbox' do
      agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: legacy_inbox, user: agent)
      create(:inbox_member, inbox: native_inbox, user: agent)

      migrate

      expect(InboxMember.where(inbox: native_inbox, user: agent).count).to eq(1)
    end

    # El canal legacy deja de reclamar el IGSID, así que el router ya no puede resolverlo
    # por la ruta antigua ni aunque la app vieja siguiera entregando
    it 'detaches instagram from the legacy channel' do
      migrate

      expect(legacy_channel.reload.instagram_id).to be_nil
    end

    # Estas tablas cuelgan de la conversación. Si no viajan con ella, los informes del
    # inbox nativo salen vacíos y los del legacy contabilizan conversaciones que ya no
    # tiene. Es justo lo que se rompe si se mueven las conversaciones antes de leerlas.
    it 'moves the satellite rows that hang off the migrated conversations' do
      ig_event = create(:reporting_event, account_id: account.id, inbox_id: legacy_inbox.id,
                                          conversation_id: ig_conversation.id, user_id: nil)
      fb_event = create(:reporting_event, account_id: account.id, inbox_id: legacy_inbox.id,
                                          conversation_id: fb_conversation.id, user_id: nil)

      migrate

      expect(ig_event.reload.inbox_id).to eq(native_inbox.id)
      expect(fb_event.reload.inbox_id).to eq(legacy_inbox.id)
    end

    it 'keeps the legacy inbox alive for messenger' do
      migrate

      expect(Inbox.find_by(id: legacy_inbox.id)).to be_present
      expect(legacy_inbox.reload.conversations.count).to eq(1)
    end
  end

  describe '.pending' do
    it 'lists the legacy inbox and points at the native one when it exists' do
      row = described_class.pending.find { |r| r[:inbox_id] == legacy_inbox.id }

      expect(row[:instagram_id]).to eq(igsid)
      expect(row[:native_inbox_id]).to eq(native_inbox.id)
      expect(row[:instagram_conversations]).to eq(1)
    end

    it 'stops listing an inbox once it has been migrated' do
      described_class.new(legacy_inbox: legacy_inbox, native_inbox: native_inbox, apply: true).perform

      expect(described_class.pending.pluck(:inbox_id)).not_to include(legacy_inbox.id)
    end
  end

  describe 'validations' do
    it 'refuses inboxes from different accounts' do
      other_native = create(:channel_instagram, account: create(:account), instagram_id: 'another-igsid').inbox

      expect { described_class.new(legacy_inbox: legacy_inbox, native_inbox: other_native).perform }
        .to raise_error(ArgumentError, /cuentas distintas/)
    end

    it 'refuses inboxes that do not point at the same instagram account' do
      mismatched_channel = create(:channel_instagram, account: account, instagram_id: 'a-different-igsid')

      expect { described_class.new(legacy_inbox: legacy_inbox, native_inbox: mismatched_channel.inbox).perform }
        .to raise_error(ArgumentError, /IGSID distinto/)
    end

    it 'refuses when the target is not a native instagram inbox' do
      expect { described_class.new(legacy_inbox: legacy_inbox, native_inbox: legacy_inbox).perform }
        .to raise_error(ArgumentError, /no es un Channel::Instagram/)
    end
  end
end
