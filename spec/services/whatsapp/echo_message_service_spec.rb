# frozen_string_literal: true

require 'rails_helper'

# @waba_templates / coexistencia — echoes del móvil → mensajes salientes en Chatwoot.
RSpec.describe Whatsapp::EchoMessageService do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }

  def echo_params(id: 'wamid.echo1', body: 'Hola desde el móvil')
    {
      phone_number: channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            metadata: {
              display_phone_number: channel.phone_number.delete('+'),
              phone_number_id: channel.provider_config['phone_number_id']
            },
            message_echoes: [{
              from: channel.phone_number.delete('+'),
              to: '5215512345678',
              id: id,
              timestamp: '1664799904',
              type: 'text',
              text: { body: body }
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  it 'crea un mensaje SALIENTE en la conversación del cliente' do
    described_class.new(inbox: inbox, params: echo_params).perform

    message = inbox.messages.last
    expect(message).to be_present
    expect(message.message_type).to eq('outgoing')
    expect(message.content).to eq('Hola desde el móvil')
    expect(message.source_id).to eq('wamid.echo1')
    expect(message.sender).to be_nil
    expect(message.content_attributes['external_created_via']).to eq('whatsapp_mobile')
    expect(message.conversation.contact.phone_number).to eq('+5215512345678')
  end

  it 'deduplica: el mismo echo dos veces no crea duplicados' do
    described_class.new(inbox: inbox, params: echo_params).perform
    described_class.new(inbox: inbox, params: echo_params).perform

    expect(inbox.messages.where(source_id: 'wamid.echo1').count).to eq(1)
  end

  it 'ignora payloads sin message_echoes' do
    params = { entry: [{ changes: [{ value: { messages: [] } }] }] }.with_indifferent_access
    expect { described_class.new(inbox: inbox, params: params).perform }.not_to change(Message, :count)
  end
end
