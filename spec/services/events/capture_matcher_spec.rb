# frozen_string_literal: true

require 'rails_helper'

# Eventos — captar en la expo «acercando el celular»: el cliente escribe por WhatsApp con
# el enlace de la etiqueta NFC y queda ligado al evento.
RSpec.describe Events::CaptureMatcher do
  let(:account) { create(:account) }
  let(:seller) { create(:user, account: account, name: 'Ana') }
  let(:channel) do
    create(:channel_whatsapp, account: account, phone_number: '+5215512345678', sync_templates: false, validate_provider_config: false)
  end
  let(:event) { Event.create!(account: account, name: 'Expo Industrial 2026', starts_at: Time.current) }
  let(:link) { event.capture_links.create!(account: account, inbox: channel.inbox, user: seller, message: 'Hola, los conocí en la Expo') }
  let(:contact) { create(:contact, account: account, phone_number: '+5215598765432') }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, contact: contact) }

  def incoming(text)
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :incoming, content: text)
  end

  it 'el enlace lleva el número de la bandeja y el mensaje con su código' do
    expect(link.code).to match(/\A[A-Z0-9]{6}\z/)
    expect(link.message).to eq("Hola, los conocí en la Expo (Ref #{link.code})")
    expect(link.url).to start_with('https://wa.me/5215512345678?text=Hola%2C%20los%20conoc')
  end

  it 'el primer mensaje con el código lo liga al evento, lo etiqueta y lo asigna al vendedor' do
    attendee = described_class.new(incoming(link.message)).call
    expect(attendee).to have_attributes(source: 'nfc', status: 'attended', contact_id: contact.id)
    expect(conversation.reload.label_list).to include('evento-expo-industrial-2026')
    expect(conversation.assignee).to eq(seller)
    expect(link.reload.captures_count).to eq(1)
  end

  it 'reconoce el código aunque el cliente cambie el texto' do
    expect(described_class.new(incoming("hola! ref: #{link.code.downcase}")).call).to be_present
  end

  it 'si ya había escrito antes, o el código es de otra bandeja, no hace nada' do
    incoming('Buenas tardes')
    expect(described_class.new(incoming(link.message)).call).to be_nil

    other = create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact)
    msg = create(:message, account: account, inbox: other.inbox, conversation: other, message_type: :incoming, content: link.message)
    expect(described_class.new(msg).call).to be_nil
    expect(link.reload.captures_count).to eq(0)
  end

  it 'no le quita la conversación a quien ya la atiende' do
    other = create(:user, account: account)
    conversation.update!(assignee: other)
    described_class.new(incoming(link.message)).call
    expect(conversation.reload.assignee).to eq(other)
  end

  it 'el listener de mensajes nuevos lo procesa' do
    message = incoming(link.message)
    EventCaptureListener.instance.message_created(Events::Base.new('message.created', Time.zone.now, message: message))
    expect(event.attendees.where(contact: contact, status: :attended)).to exist
  end

  it 'solo acepta bandejas de WhatsApp' do
    web = event.capture_links.new(account: account, inbox: create(:inbox, account: account), message: 'x')
    expect(web).not_to be_valid
    expect(web.errors[:inbox]).to be_present
  end
end
