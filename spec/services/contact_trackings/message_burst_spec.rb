# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::MessageBurst do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:template) { create(:tracking_template, account: account) }

  def mensaje(tipo, texto)
    create(:message, account: account, conversation: conversation, message_type: tipo, content: texto)
  end

  it 'apagado por defecto: 0 segundos aunque haya seguimiento' do
    create(:contact_tracking, account: account, conversation: conversation, inbox: conversation.inbox, contact: conversation.contact,
                              tracking_template: template, status: 'active')
    expect(described_class.seconds_for(conversation.id)).to eq(0)
  end

  it 'con la opción del agente, sus segundos (con tope)' do
    template.update!(resources: { 'group_seconds' => 90 })
    create(:contact_tracking, account: account, conversation: conversation, inbox: conversation.inbox, contact: conversation.contact,
                              tracking_template: template, status: 'active')
    expect(described_class.seconds_for(conversation.id)).to eq(described_class::MAX_SECONDS)
  end

  it 'junta los mensajes del cliente que siguen sin respuesta' do
    mensaje(:incoming, 'Hola')
    mensaje(:outgoing, '¿Qué día nos visitas?')
    primero = mensaje(:incoming, 'El sbaa')
    ultimo = mensaje(:incoming, 'Sábado')

    expect(described_class.newer_incoming?(primero)).to be(true)
    expect(described_class.newer_incoming?(ultimo)).to be(false)
    expect(described_class.text(ultimo)).to eq("El sbaa\nSábado")
    expect(described_class.text(primero)).to be_nil
  end

  describe 'en el análisis (ContactTrackingResponseAnalyzerJob#take_burst)' do
    let(:job) { ContactTrackingResponseAnalyzerJob.new }

    before do
      template.update!(resources: { 'group_seconds' => 8 })
      create(:contact_tracking, account: account, conversation: conversation, inbox: conversation.inbox, contact: conversation.contact,
                                tracking_template: template, status: 'active')
    end

    it 'el primero de la ráfaga no contesta; el último contesta con el texto de los dos' do
      primero = mensaje(:incoming, 'El sbaa')
      ultimo = mensaje(:incoming, 'Sábado')

      expect(job.send(:take_burst, primero)).to be(false)
      expect(job.send(:take_burst, ultimo)).to be(true)
      expect(ultimo.content).to eq("El sbaa\nSábado")
      expect(ultimo.reload.content).to eq('Sábado')
    end

    it 'sin la opción contesta cada mensaje como siempre' do
      template.update!(resources: {})
      primero = mensaje(:incoming, 'El sbaa')
      mensaje(:incoming, 'Sábado')
      expect(job.send(:take_burst, primero)).to be(true)
      expect(primero.content).to eq('El sbaa')
    end
  end
end
