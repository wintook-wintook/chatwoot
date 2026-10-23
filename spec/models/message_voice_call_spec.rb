# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3, D6) — la burbuja de una llamada no es un mensaje que se
# mande al cliente ni que lean bots o seguimientos.
RSpec.describe Message do
  let(:conversation) { create(:conversation) }

  def burbuja(message_type)
    create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                     message_type: message_type, content_type: :voice_call, content: 'Llamada de WhatsApp')
  end

  it 'no la mandan los servicios de envío' do
    servicio = Whatsapp::SendOnWhatsappService.new(message: burbuja(:outgoing))
    expect(servicio.send(:invalid_message?)).to be(true)
  end

  it 'no la reciben bots ni webhooks externos' do
    expect(burbuja(:incoming).webhook_sendable?).to be(false)
  end

  it 'no la analizan los seguimientos ni BotSeller' do
    allow(ContactTrackingResponseAnalyzerJob).to receive(:set).and_call_original
    burbuja(:incoming)
    expect(ContactTrackingResponseAnalyzerJob).not_to have_received(:set)
  end

  it 'un mensaje normal sí sigue su camino' do
    mensaje = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox, message_type: :incoming)
    expect(mensaje.webhook_sendable?).to be(true)
  end
end
