require 'rails_helper'

RSpec.describe ContactTrackings::PaymentConfirmedJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation,
                              appointment_status: 'pending_payment', appointment_event_id: 'evt1',
                              appointment_at: Time.find_zone('America/Mexico_City').local(2026, 9, 28, 9))
  end
  let(:confirmacion) { instance_double(ContactTrackings::ServiceConfirmation, open?: true, when_text: 'lunes 28 de septiembre a las 09:00') }

  before do
    tracking
    allow(ContactTrackings::ServiceConfirmation).to receive(:new).and_return(confirmacion)
  end

  it 'deja en firme el servicio y se lo avisa al cliente' do
    allow(confirmacion).to receive(:confirm!).and_return(true)

    described_class.perform_now(conversation.id)
    publico = conversation.messages.where(private: false).last
    expect(publico.content).to eq('✅ Recibimos tu pago. Tu servicio del lunes 28 de septiembre a las 09:00 quedó confirmado.')
    expect(conversation.messages.where(private: true).last.content).to include('Pago confirmado')
  end

  it 'si el calendario no respondió, solo deja nota para el equipo' do
    allow(confirmacion).to receive(:confirm!).and_return(false)

    described_class.perform_now(conversation.id)
    expect(conversation.messages.where(private: false)).to be_empty
    expect(conversation.messages.where(private: true).last.content).to include('Confírmalo a mano')
  end
end
