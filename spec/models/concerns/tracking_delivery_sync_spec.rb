# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — el webhook de estado de WhatsApp actualiza el Message;
# ese cambio llega al envío del seguimiento.
RSpec.describe TrackingDeliverySync do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tracking) { create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation_id: conversation.id) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                     content: 'seguimiento', source_id: 'wamid.prueba')
  end
  let!(:delivery) do
    TrackingDelivery.create!(account: account, contact_tracking: tracking, message: message, source_id: message.source_id,
                             kind: 'template', attempt_number: 1, status: 'sent', sent_at: Time.current)
  end

  it 'delivered y read del mensaje pasan al envío' do
    message.update!(status: :delivered)
    expect(delivery.reload.status).to eq('delivered')

    message.update!(status: :read)
    expect(delivery.reload.status).to eq('read')
  end

  it 'failed guarda el error de Meta y encola la decisión de reintento' do
    expect do
      message.update!(status: :failed, external_error: '130429: Rate limit hit')
    end.to have_enqueued_job(TrackingDeliveries::FailureJob).with(delivery.id)

    expect(delivery.reload).to have_attributes(status: 'failed', error_code: '130429', error_kind: 'temporary')
  end

  it 'los mensajes que no son de un seguimiento no hacen nada' do
    other = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'otro')

    expect { other.update!(status: :failed, external_error: '131026: x') }.not_to have_enqueued_job(TrackingDeliveries::FailureJob)
  end

  describe TrackingDeliveries::UnconfirmedJob do
    it 'lo enviado hace más de 24 h sin confirmar pasa a "sin confirmar"' do
      delivery.update!(sent_at: 25.hours.ago)
      fresh = TrackingDelivery.create!(account: account, contact_tracking: tracking, kind: 'session', attempt_number: 2,
                                       status: 'sent', sent_at: 1.hour.ago)

      described_class.perform_now

      expect(delivery.reload.status).to eq('unconfirmed')
      expect(fresh.reload.status).to eq('sent')
    end
  end
end
