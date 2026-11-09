# frozen_string_literal: true

require 'rails_helper'

# Portal de Dali en el teléfono: botones rápidos, dictado y el enlace de un solo uso del QR.
RSpec.describe 'Assistant portal API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:base)    { "/api/v1/accounts/#{account.id}/assistant" }

  it 'manda los botones rápidos según los permisos' do
    get base, headers: admin.create_new_auth_token, as: :json
    keys = response.parsed_body['shortcuts'].pluck('key')
    expect(keys).to eq(%w[today reply quote route meeting note sales])
    expect(response.parsed_body['shortcuts'].first).to include('label' => I18n.t('assistant.shortcuts.today.label'))
  end

  describe 'dictado' do
    let(:audio) { Rack::Test::UploadedFile.new(StringIO.new('RIFF....'), 'audio/webm', original_filename: 'dictado.webm') }

    it 'regresa el texto de la nota de voz' do
      allow_any_instance_of(Assistant::Transcriber).to receive(:call).and_return('agéndame una llamada mañana') # rubocop:disable RSpec/AnyInstance
      post "#{base}/transcribe", params: { audio: audio }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['text']).to eq('agéndame una llamada mañana')
    end

    it 'avisa si no se entendió' do
      allow_any_instance_of(Assistant::Transcriber).to receive(:call).and_return(nil) # rubocop:disable RSpec/AnyInstance
      post "#{base}/transcribe", params: { audio: audio }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('No se entendió')
    end

    it 'pide el audio' do
      post "#{base}/transcribe", headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'el enlace del QR entra firmado una sola vez y regresa a Dali de esta empresa' do
    post "#{base}/mobile_link", headers: admin.create_new_auth_token, as: :json
    url = response.parsed_body['url']
    query = Rack::Utils.parse_query(URI(url).query)
    expect(URI(url).path).to eq('/app/login')
    expect(query).to include('email' => admin.email, 'sso_account_id' => account.id.to_s, 'redirect' => 'dali')
    expect(response.parsed_body['expires_in']).to eq(300)

    post '/auth/sign_in', params: { email: admin.email, sso_auth_token: query['sso_auth_token'] }, as: :json
    expect(response).to have_http_status(:ok)
    expect(admin.valid_sso_auth_token?(query['sso_auth_token'])).to be(false)
  end

  it 'sin sesión no hay enlace' do
    post "#{base}/mobile_link", as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
