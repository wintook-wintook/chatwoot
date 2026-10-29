require 'rails_helper'

# TikTok no hace handshake de verificación como Meta: firma cada petición. Si esta
# comprobación se afloja, cualquiera puede inyectar mensajes en las conversaciones.
RSpec.describe 'Webhooks::TiktokController', type: :request do
  let(:secret) { 'tiktok-app-secret' }
  let(:payload) { { event: 'im_receive_msg', user_openid: 'biz-1', content: '{}' }.to_json }

  def signature_header(body, secret_key: secret, timestamp: Time.current.to_i)
    digest = OpenSSL::HMAC.hexdigest('SHA256', secret_key, "#{timestamp}.#{body}")
    "t=#{timestamp},s=#{digest}"
  end

  def post_webhook(body, header)
    post '/webhooks/tiktok', params: body, headers: { 'Tiktok-Signature' => header, 'CONTENT_TYPE' => 'application/json' }
  end

  around do |example|
    original = ENV.fetch('TIKTOK_APP_SECRET', nil)
    ENV['TIKTOK_APP_SECRET'] = secret
    GlobalConfig.clear_cache
    example.run
    ENV['TIKTOK_APP_SECRET'] = original
    GlobalConfig.clear_cache
  end

  describe 'POST /webhooks/tiktok' do
    it 'accepts a correctly signed event' do
      expect(Webhooks::TiktokEventsJob).to receive(:perform_later)

      post_webhook(payload, signature_header(payload))

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a signature made with another secret' do
      post_webhook(payload, signature_header(payload, secret_key: 'otro'))

      expect(response).to have_http_status(:unauthorized)
    end

    # El cuerpo forma parte de lo firmado: cambiarlo invalida la firma
    it 'rejects a tampered body' do
      header = signature_header(payload)

      post_webhook(payload.sub('biz-1', 'biz-2'), header)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a replayed request older than the accepted window' do
      old = 60.seconds.ago.to_i

      post_webhook(payload, signature_header(payload, timestamp: old))

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a request with no signature header' do
      post '/webhooks/tiktok', params: payload, headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    # El eco puede llegar antes de que termine la llamada que envió el mensaje
    it 'delays echo events' do
      echo = { event: 'im_send_msg', user_openid: 'biz-1', content: '{}' }.to_json

      post_webhook(echo, signature_header(echo))

      expect(response).to have_http_status(:ok)
      expect(Webhooks::TiktokEventsJob).to have_been_enqueued.at(a_value_within(1.second).of(2.seconds.from_now))
    end

    it 'processes a normal event without waiting' do
      post_webhook(payload, signature_header(payload))

      expect(Webhooks::TiktokEventsJob).to have_been_enqueued.at(:no_wait)
    end
  end
end
