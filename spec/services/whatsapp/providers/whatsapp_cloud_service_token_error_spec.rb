# frozen_string_literal: true

require 'rails_helper'

# diag/waba F3 (D6) — un envío con el permiso de Meta vencido cuenta para «requiere reconexión».
describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:message) { create(:message, conversation: create(:conversation, inbox: whatsapp_channel.inbox), content: 'hola') }
  let(:url) { %r{graph\.facebook\.com/v\d+\.\d+/123456789/messages} }

  def meta_answers(status, body)
    stub_request(:post, url).to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'token vencido (190): el mensaje falla y suma un error de autorización' do
    meta_answers(401, { error: { message: 'Error validating access token', type: 'OAuthException', code: 190 } })
    allow(whatsapp_channel).to receive(:authorization_error!)

    expect(service.send_message('+123456789', message)).to be_nil
    expect(message.reload.status).to eq('failed')
    expect(whatsapp_channel).to have_received(:authorization_error!)
  end

  it 'dos envíos con token vencido marcan la bandeja para reconexión' do
    meta_answers(400, { error: { message: 'Session has expired', code: 190 } })
    2.times { service.send_message('+123456789', message) }
    expect(whatsapp_channel.reauthorization_required?).to be(true)
  end

  it 'otros errores (ventana de 24 h) no cuentan' do
    meta_answers(400, { error: { message: 'Re-engagement message', code: 131_047 } })
    allow(whatsapp_channel).to receive(:authorization_error!)

    service.send_message('+123456789', message)
    expect(whatsapp_channel).not_to have_received(:authorization_error!)
  end
end
