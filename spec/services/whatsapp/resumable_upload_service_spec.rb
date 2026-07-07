# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — Resumable Upload de imagen de cabecera (2 pasos → handle).
RSpec.describe Whatsapp::ResumableUploadService do
  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:media_url) { 'https://cdn.example.com/header.png' }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:graph) { 'https://graph.facebook.com/v20.0' }

  before do
    allow(GlobalConfigService).to receive(:load).with('FB_APP_ID', nil).and_return('APP123')
  end

  def stub_media(content_type: 'image/png', length: '8', body: 'PNG-DATA')
    stub_request(:get, media_url).to_return(status: 200, body: body,
                                            headers: { 'Content-Type' => content_type, 'Content-Length' => length })
  end

  it 'completa el flujo de 2 pasos y devuelve el handle' do
    stub_media
    stub_request(:post, "#{graph}/APP123/uploads")
      .with(query: hash_including({ 'file_type' => 'image/png', 'access_token' => 'test_key' }))
      .to_return(status: 200, body: { id: 'upload:sess123' }.to_json, headers: json)
    stub_request(:post, "#{graph}/upload:sess123")
      .with(headers: { 'Authorization' => 'OAuth test_key' })
      .to_return(status: 200, body: { h: 'HANDLE123' }.to_json, headers: json)

    result = described_class.new(channel: whatsapp_channel, media_url: media_url).perform
    expect(result).to have_attributes(success: true, handle: 'HANDLE123')
  end

  it 'rechaza tipos no permitidos' do
    stub_media(content_type: 'image/gif')
    result = described_class.new(channel: whatsapp_channel, media_url: media_url).perform
    expect(result.success?).to be(false)
    expect(result.error).to match(/Tipo no permitido/)
  end

  it 'rechaza imágenes > 5 MB' do
    stub_media(length: (6 * 1024 * 1024).to_s)
    result = described_class.new(channel: whatsapp_channel, media_url: media_url).perform
    expect(result.success?).to be(false)
    expect(result.error).to match(/supera/)
  end

  it 'falla si no hay App ID configurado' do
    allow(GlobalConfigService).to receive(:load).with('FB_APP_ID', nil).and_return(nil)
    result = described_class.new(channel: whatsapp_channel, media_url: media_url).perform
    expect(result.error).to match(/META_APP_ID/)
  end
end
