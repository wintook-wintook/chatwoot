# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 1: el job registra cada envío por WhatsApp y,
# si Meta lo rechaza al momento, decide por el tipo de error. Meta se simula con webmock.
RSpec.describe ContactTrackingJob do
  let!(:account) { create(:account) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, account: account, phone_number: '+5215512345678') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let!(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation_id: conversation.id,
                              status: 'scheduled', scheduled_for: 1.hour.from_now)
      .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
  end

  before do
    # Ventana de 24 h abierta: sale como mensaje de sesión (sin plantilla).
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'hola', created_at: 1.hour.ago)
    allow_any_instance_of(described_class).to receive(:generate_message).and_return('mensaje de seguimiento') # rubocop:disable RSpec/AnyInstance
  end

  def meta_responds(status, body)
    stub_request(:post, %r{graph\.facebook\.com/.*/messages})
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'Meta acepta: registra el envío con su mensaje y source_id' do
    meta_responds(200, { messages: [{ id: 'wamid.ok' }] })

    described_class.perform_now(tracking.id)

    delivery = tracking.tracking_deliveries.last
    expect(delivery).to have_attributes(status: 'sent', kind: 'session', attempt_number: 1, source_id: 'wamid.ok')
    expect(delivery.message.source_id).to eq('wamid.ok')
    expect(tracking.reload.attempt_count).to eq(1)
  end

  context 'when Meta rechaza al momento' do
    it 'con error temporal reprograma el mismo intento y no guarda el mensaje rechazado' do
      meta_responds(400, { error: { message: 'Rate limit hit', code: 130_429 } })

      expect { described_class.perform_now(tracking.id) }.not_to change(conversation.messages.outgoing, :count)

      expect(tracking.tracking_deliveries.last).to have_attributes(status: 'failed', error_code: '130429',
                                                                   error_kind: 'temporary', next_retry_at: be_present)
      expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 0)
      expect(tracking.scheduled_for).to be_within(10.seconds).of(5.minutes.from_now)
    end

    it 'con error permanente el seguimiento falla con el motivo de Meta, como antes' do
      meta_responds(400, { error: { message: '(#100) Invalid parameter', code: 100, error_data: { details: 'Param text invalid' } } })

      described_class.perform_now(tracking.id)

      expect(tracking.reload).to have_attributes(status: 'failed', last_error: 'Meta 100: Param text invalid')
    end
  end
end
