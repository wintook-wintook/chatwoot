# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contpaq::TokenProvider do
  let(:account) { create(:account) }
  let(:source) do
    account.knowledge_sources.create!(
      name: 'Agente CONTPAQi', source_type: 'contpaq_support',
      config: { 'token_url' => 'https://login.test/oauth2/v2.0/token', 'client_id' => 'cid',
                'client_secret' => 'secret', 'scope' => 'api://x/.default' }
    )
  end
  let(:provider) { described_class.new(source) }

  def stub_token(expires_in: 3599, token: 'jwt-abc')
    stub_request(:post, 'https://login.test/oauth2/v2.0/token')
      .to_return(status: 200, body: { access_token: token, expires_in: expires_in }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  after { Redis::Alfred.delete(format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: source.id)) }

  it 'pide el token con client_credentials y lo devuelve' do
    stub_token
    expect(provider.token).to eq('jwt-abc')
    expect(WebMock).to have_requested(:post, 'https://login.test/oauth2/v2.0/token')
      .with(body: hash_including('grant_type' => 'client_credentials', 'client_id' => 'cid'))
  end

  it 'no pide un token por llamada: reusa el cacheado' do
    stub_token
    3.times { provider.token }
    expect(WebMock).to have_requested(:post, 'https://login.test/oauth2/v2.0/token').once
  end

  it 'lo cachea con margen para no usarlo justo al vencer' do
    stub_token(expires_in: 3599)
    allow(Redis::Alfred).to receive(:set).and_call_original
    provider.token

    expect(Redis::Alfred).to have_received(:set)
      .with(anything, 'jwt-abc', ex: 3599 - described_class::EXPIRY_MARGIN)
  end

  it 'no cachea una vigencia menor al margen' do
    stub_token(expires_in: 60)
    expect(provider.token).to eq('jwt-abc')
    expect(Redis::Alfred.get(format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: source.id))).to be_nil
  end

  it 'invalidate! obliga a pedir uno nuevo' do
    stub_token
    provider.token
    provider.invalidate!
    provider.token
    expect(WebMock).to have_requested(:post, 'https://login.test/oauth2/v2.0/token').twice
  end

  it 'devuelve nil si el proveedor rechaza las credenciales' do
    stub_request(:post, 'https://login.test/oauth2/v2.0/token')
      .to_return(status: 401, body: { error: 'invalid_client' }.to_json)
    expect(provider.token).to be_nil
  end

  it 'devuelve nil si la fuente no esta configurada' do
    source.update!(config: {})
    expect(described_class.new(source).token).to be_nil
  end
end
