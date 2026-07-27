require 'rails_helper'

RSpec.describe Instagram::OauthService do
  subject(:service) { described_class.new }

  before do
    # upsert: ConfigLoader ya siembra estas claves, crearlas de nuevo choca con el índice único
    { 'IG_APP_ID' => 'ig-app-id', 'IG_APP_SECRET' => 'ig-app-secret' }.each do |name, value|
      InstallationConfig.find_or_initialize_by(name: name).update!(value: value)
    end
    GlobalConfig.clear_cache
  end

  describe '#authorize_url' do
    it 'points at instagram.com with the business scopes and the state' do
      url = service.authorize_url(state: 'a-state')

      expect(url).to start_with('https://www.instagram.com/oauth/authorize?')
      expect(url).to include('client_id=ig-app-id')
      expect(url).to include('state=a-state')
      expect(url).to include(CGI.escape('instagram_business_basic,instagram_business_manage_messages'))
      expect(url).to include(CGI.escape(service.redirect_uri))
    end
  end

  describe '#redirect_uri' do
    it 'derives from FRONTEND_URL instead of a dedicated config' do
      expect(service.redirect_uri).to eq("#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/instagram/callback")
    end
  end

  describe '#exchange_code' do
    it 'returns the short lived token' do
      stub_request(:post, 'https://api.instagram.com/oauth/access_token')
        .to_return(status: 200, body: { access_token: 'short-token', user_id: 17_841_400 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.exchange_code('the-code')

      expect(result[:access_token]).to eq('short-token')
      expect(result[:user_id]).to eq(17_841_400)
    end

    it 'raises OauthError with the message returned by Meta' do
      stub_request(:post, 'https://api.instagram.com/oauth/access_token')
        .to_return(status: 400, body: { error_message: 'Invalid authorization code' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { service.exchange_code('bad-code') }
        .to raise_error(described_class::OauthError, /Invalid authorization code/)
    end
  end

  describe '#exchange_long_lived_token' do
    it 'returns the 60 day token and its lifetime' do
      stub_request(:get, %r{graph\.instagram\.com/access_token})
        .to_return(status: 200, body: { access_token: 'long-token', token_type: 'bearer', expires_in: 5_184_000 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.exchange_long_lived_token('short-token')

      expect(result[:access_token]).to eq('long-token')
      expect(result[:expires_in]).to eq(5_184_000)
    end
  end

  describe '#refresh_long_lived_token' do
    it 'asks for a new 60 day window' do
      stub = stub_request(:get, %r{graph\.instagram\.com/refresh_access_token})
             .to_return(status: 200, body: { access_token: 'refreshed', expires_in: 5_184_000 }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      expect(service.refresh_long_lived_token('long-token')[:access_token]).to eq('refreshed')
      expect(stub).to have_been_requested
    end
  end

  describe '#fetch_profile' do
    it 'returns the business account profile' do
      stub_request(:get, %r{graph\.instagram\.com/.*/me})
        .to_return(status: 200,
                   body: { user_id: '17841400', username: 'chatwoot', name: 'Chatwoot',
                           profile_picture_url: 'https://cdn/pic.jpg' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      profile = service.fetch_profile('long-token')

      expect(profile[:username]).to eq('chatwoot')
      expect(profile[:user_id]).to eq('17841400')
    end

    it 'raises OauthError when Meta answers with an error object' do
      stub_request(:get, %r{graph\.instagram\.com/.*/me})
        .to_return(status: 401, body: { error: { message: 'Invalid OAuth access token' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { service.fetch_profile('nope') }
        .to raise_error(described_class::OauthError, /Invalid OAuth access token/)
    end
  end
end
