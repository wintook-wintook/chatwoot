# frozen_string_literal: true

require 'rails_helper'

# Anuncio de clic a WhatsApp: el `referral` de Meta queda en el mensaje y, la primera vez, en la conversación
# (Whatsapp::IncomingMessageBaseService#note_ad_referral). Lo usa el agente de Atención a prospectos.
RSpec.describe Whatsapp::IncomingMessageService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(inbox: inbox, params: {}) }

  def note(referral)
    message = conversation.messages.build(content: 'info', account_id: account.id, inbox_id: inbox.id, message_type: :incoming)
    service.instance_variable_set(:@conversation, conversation)
    service.instance_variable_set(:@message, message)
    service.send(:note_ad_referral, { referral: referral })
    message
  end

  it 'guarda de qué anuncio viene en el mensaje y en la conversación (solo el primero)' do
    message = note({ headline: 'Camionetas 2019', body: 'Desde $199,000', source_url: 'https://fb.me/x', ctwa_clid: 'abc' })
    expect(message.content_attributes['referral']).to include('headline' => 'Camionetas 2019', 'ctwa_clid' => 'abc')
    expect(conversation.reload.additional_attributes['ad_referral']).to include('headline' => 'Camionetas 2019')

    note({ headline: 'Otro anuncio' })
    expect(conversation.reload.additional_attributes.dig('ad_referral', 'headline')).to eq('Camionetas 2019')
  end

  it 'sin referral no toca nada' do
    expect(note(nil).content_attributes.to_h).not_to have_key('referral')
  end
end
