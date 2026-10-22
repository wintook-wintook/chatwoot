# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F2) — la Calling API de Meta.
RSpec.describe Whatsapp::Providers::WhatsappCloudCalls do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:service) { Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: channel) }
  let(:calls_url) { 'https://graph.facebook.com/v22.0/123456789/calls' }
  let(:settings_url) { 'https://graph.facebook.com/v22.0/123456789/settings' }

  it 'contestar manda pre_accept y accept con el SDP answer' do
    stub_request(:post, calls_url).with(body: hash_including('action' => 'pre_accept', 'call_id' => 'wacid.1',
                                                             'session' => { 'sdp' => 'v=0', 'sdp_type' => 'answer' }))
                                  .to_return(status: 200, body: '{"success":true}')
    stub_request(:post, calls_url).with(body: hash_including('action' => 'accept')).to_return(status: 200, body: '{"success":true}')

    expect(service.pre_accept_call('wacid.1', 'v=0')).to be(true)
    expect(service.accept_call('wacid.1', 'v=0')).to be(true)
  end

  it 'rechazar y colgar devuelven false si Meta falla, sin levantar' do
    stub_request(:post, calls_url).to_return(status: 400, body: '{"error":{"message":"x"}}')

    expect(service.reject_call('wacid.1')).to be(false)
    expect(service.terminate_call('wacid.1')).to be(false)
  end

  describe '#initiate_call' do
    it 'devuelve el id de la llamada que crea Meta' do
      stub_request(:post, calls_url).with(body: hash_including('action' => 'connect', 'to' => '5215512345678'))
                                    .to_return(status: 200, body: '{"calls":[{"id":"wacid.9"}]}', headers: { 'Content-Type' => 'application/json' })

      expect(service.initiate_call('+5215512345678', 'v=0 offer').dig('calls', 0, 'id')).to eq('wacid.9')
    end

    it 'sin permiso del cliente (138006) levanta NoCallPermission' do
      stub_request(:post, calls_url).to_return(status: 400, body: '{"error":{"code":138006,"message":"No permission"}}',
                                               headers: { 'Content-Type' => 'application/json' })

      expect { service.initiate_call('5215512345678', 'v=0') }.to raise_error(Voice::CallErrors::NoCallPermission, 'No permission')
    end

    it 'otro error levanta CallFailed con el mensaje de Meta' do
      stub_request(:post, calls_url).to_return(status: 400, body: '{"error":{"code":131044,"error_user_msg":"","message":"No elegible"}}',
                                               headers: { 'Content-Type' => 'application/json' })

      expect { service.initiate_call('5215512345678', 'v=0') }.to raise_error(Voice::CallErrors::CallFailed, 'No elegible')
    end
  end

  it 'activar con «solo salientes» oculta el botón de llamar al cliente' do
    stub = stub_request(:post, settings_url).with(body: { calling: { status: 'ENABLED', call_icon_visibility: 'DISABLE_ALL' } }.to_json)
                                            .to_return(status: 200, body: '{"success":true}')

    expect(service.update_calling_status('ENABLED', icon: 'DISABLE_ALL')).to be(true)
    expect(stub).to have_been_requested
  end

  it 'si Meta no deja activar, levanta con su mensaje' do
    stub_request(:post, settings_url)
      .to_return(status: 400, body: '{"error":{"error_user_msg":"Límite de mensajería insuficiente"}}',
                 headers: { 'Content-Type' => 'application/json' })

    expect { service.update_calling_status('ENABLED') }.to raise_error(RuntimeError, 'Límite de mensajería insuficiente')
  end

  it 'lee la configuración de llamadas del número' do
    stub_request(:get, settings_url)
      .to_return(status: 200, body: '{"calling":{"status":"NOT_SET"}}', headers: { 'Content-Type' => 'application/json' })

    expect(service.calling_settings).to eq('status' => 'NOT_SET')
  end

  it 'manda la solicitud de permiso como mensaje interactivo' do
    stub_request(:post, 'https://graph.facebook.com/v22.0/123456789/messages')
      .with(body: hash_including('type' => 'interactive', 'interactive' => hash_including('type' => 'call_permission_request')))
      .to_return(status: 200, body: '{"messages":[{"id":"wamid.1"}]}', headers: { 'Content-Type' => 'application/json' })

    expect(service.send_call_permission_request('5215512345678', '¿Te podemos llamar?').dig('messages', 0, 'id')).to eq('wamid.1')
  end
end
