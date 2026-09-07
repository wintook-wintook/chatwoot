require 'rails_helper'

# Solo cubre la guarda de ventana de Instagram añadida en F8. El resto del job es
# preexistente y queda fuera. Ver docs/instagram_plan.md §6 F8
RSpec.describe ContactTrackingJob do
  let!(:account) { create(:account) }
  let!(:channel) { create(:channel_instagram, account: account) }
  let(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'ig-contact') }
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { type: 'instagram_direct_message' })
  end
  let!(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                              conversation_id: conversation.id, status: 'scheduled', scheduled_for: 1.hour.from_now)
      .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
  end

  def incoming_message_at(time)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :incoming, content: 'hola', created_at: time)
  end

  describe 'instagram messaging window' do
    context 'when the window is closed' do
      before { incoming_message_at(48.hours.ago) }

      # Instagram no tiene plantillas: enviar fuera de ventana solo consigue que Meta lo
      # rechace, gastando un intento y dando por bueno un mensaje que nadie recibe.
      it 'fails the tracking instead of burning an attempt' do
        described_class.perform_now(tracking.id)

        tracking.reload
        expect(tracking.status).to eq('failed')
        expect(tracking.last_error).to match(/window closed/)
      end

      it 'does not create an outgoing message' do
        expect { described_class.perform_now(tracking.id) }
          .not_to change(conversation.messages.outgoing, :count)
      end
    end

    context 'when there is no history at all' do
      it 'treats the window as closed' do
        described_class.perform_now(tracking.id)

        expect(tracking.reload.status).to eq('failed')
      end
    end

    context 'when the customer wrote recently' do
      before { incoming_message_at(2.hours.ago) }

      it 'does not block the tracking' do
        allow_any_instance_of(described_class).to receive(:generate_message).and_return('mensaje de seguimiento') # rubocop:disable RSpec/AnyInstance

        described_class.perform_now(tracking.id)

        expect(tracking.reload.status).not_to eq('failed')
      end
    end

    context 'with the HUMAN_AGENT tag enabled' do
      before do
        InstallationConfig.find_or_initialize_by(name: 'ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT').update!(value: true)
        GlobalConfig.clear_cache
        incoming_message_at(3.days.ago)
      end

      after do
        InstallationConfig.find_by(name: 'ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT')&.update!(value: false)
        GlobalConfig.clear_cache
      end

      # Con el tag aprobado la ventana se amplía a 7 días, igual que en can_reply_on_instagram?
      it 'still allows sending after 24 hours' do
        allow_any_instance_of(described_class).to receive(:generate_message).and_return('mensaje de seguimiento') # rubocop:disable RSpec/AnyInstance

        described_class.perform_now(tracking.id)

        expect(tracking.reload.status).not_to eq('failed')
      end
    end
  end

  # Bug preexistente descubierto al añadir la guarda de Instagram: en Rails 7.0 salir con
  # `return` de un bloque with_lock revierte la transacción, así que el estado 'failed' se
  # descartaba y el seguimiento se quedaba en 'scheduled', reintentándose para siempre.
  describe 'whatsapp with the window closed and no template' do
    let!(:wa_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let!(:wa_inbox) { create(:inbox, channel: wa_channel, account: account) }
    let(:wa_contact) { create(:contact, account: account) }
    let(:wa_contact_inbox) { create(:contact_inbox, contact: wa_contact, inbox: wa_inbox, source_id: '123456789') }
    let!(:wa_conversation) do
      create(:conversation, account: account, inbox: wa_inbox, contact: wa_contact, contact_inbox: wa_contact_inbox)
    end
    let!(:wa_tracking) do
      create(:contact_tracking, account: account, contact: wa_contact, inbox: wa_inbox,
                                conversation_id: wa_conversation.id, status: 'scheduled', scheduled_for: 1.hour.from_now)
        .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
    end

    it 'persists the failed status instead of silently retrying forever' do
      described_class.perform_now(wa_tracking.id)

      wa_tracking.reload
      expect(wa_tracking.status).to eq('failed')
      expect(wa_tracking.last_error).to match(/window closed/)
    end
  end

  describe 'legacy instagram inboxes' do
    let!(:legacy_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'legacy-igsid') }
    let!(:legacy_inbox) { create(:inbox, channel: legacy_channel, account: account) }
    let(:legacy_contact) { create(:contact, account: account) }
    let(:legacy_contact_inbox) { create(:contact_inbox, contact: legacy_contact, inbox: legacy_inbox, source_id: 'psid') }
    let!(:legacy_conversation) do
      create(:conversation, account: account, inbox: legacy_inbox, contact: legacy_contact, contact_inbox: legacy_contact_inbox)
    end
    let!(:legacy_tracking) do
      create(:contact_tracking, account: account, contact: legacy_contact, inbox: legacy_inbox,
                                conversation_id: legacy_conversation.id, status: 'scheduled', scheduled_for: 1.hour.from_now)
        .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
    end

    before { stub_request(:post, %r{graph\.facebook\.com/.*/subscribed_apps}) }

    # En un inbox legacy conviven Messenger e Instagram y no se puede distinguir a cuál
    # pertenece el seguimiento, así que ese camino se deja tal como estaba.
    it 'keeps behaving exactly as before, without the new guard' do
      allow_any_instance_of(described_class).to receive(:generate_message).and_return('mensaje') # rubocop:disable RSpec/AnyInstance

      described_class.perform_now(legacy_tracking.id)

      expect(legacy_tracking.reload.status).not_to eq('failed')
    end
  end
end
