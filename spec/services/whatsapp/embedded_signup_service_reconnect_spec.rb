# frozen_string_literal: true

require 'rails_helper'

# diag/waba F3 — «Reconectar con Meta» sobre una bandeja existente.
RSpec.describe Whatsapp::EmbeddedSignupService do
  let(:account) { create(:account) }
  let(:client) { instance_double(Whatsapp::FacebookApiClient) }
  let(:ok) { instance_double(HTTParty::Response, success?: true) }
  let!(:channel) do
    ch = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', phone_number: '+5213121401826',
                                   sync_templates: false, validate_provider_config: false)
    ch.update_column(:provider_config, { 'api_key' => 'viejo', 'phone_number_id' => 'ph1', 'business_account_id' => 'waba1', # rubocop:disable Rails/SkipsModelValidations
                                         'webhook_verify_token' => 'vt' })
    ch
  end
  let(:params) { { code: 'c', business_id: 'b', waba_id: 'waba1', phone_number_id: 'ph1', inbox_id: channel.inbox.id } }

  around { |example| I18n.with_locale(:es) { example.run } }

  before do
    allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(client)
    allow(client).to receive_messages(exchange_code_for_token: 'nuevo', validate_token_access: true,
                                      subscribe_app: ok, subscribe_webhook: ok, register_phone: ok)
    phone = { phone_number_id: 'ph1', phone_number: '+5213121401826', verified: false, business_name: 'X' }
    allow(client).to receive(:fetch_phone_info).and_return(phone)
    # con el token nuevo la bandeja vuelve a sincronizar sus plantillas
    stub_request(:get, /message_templates/).to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def reconnect
    described_class.new(account: account, params: params).perform
  end

  it 'mismo número: token nuevo en la MISMA bandeja y sin la marca de reconexión' do
    expect { reconnect }.not_to change(Channel::Whatsapp, :count)

    config = channel.reload.provider_config
    expect(config).to include('api_key' => 'nuevo', 'phone_number_id' => 'ph1', 'webhook_verify_token' => 'vt')
    expect(channel.reauthorization_required?).to be(false)
  end

  it 'alta a mano: conserva su origen, solo suscribe la app (sin URL de este servidor) y NO registra el número' do
    reconnect

    expect(channel.reload.provider_config['source']).to be_nil
    expect(client).to have_received(:subscribe_app).with('waba1', 'nuevo')
    expect(client).not_to have_received(:subscribe_webhook)
    expect(client).not_to have_received(:register_phone)
  end

  it 'alta con Meta: re-suscribe con la URL de este servidor' do
    channel.update_column(:provider_config, channel.provider_config.merge('source' => 'embedded_signup')) # rubocop:disable Rails/SkipsModelValidations
    reconnect

    expect(client).to have_received(:subscribe_webhook).with('waba1', 'nuevo', %r{/webhooks/whatsapp/}, 'vt')
    expect(client).not_to have_received(:subscribe_app)
  end

  it 'otro número: no toca la bandeja y dice cuál eligió' do
    allow(client).to receive(:fetch_phone_info).and_return({ phone_number_id: 'ph9', phone_number: '+5215500000000', verified: true })

    expect { reconnect }.to raise_error(ArgumentError, /otro número \(\+5215500000000\)/)
    expect(channel.reload.provider_config['api_key']).to eq('viejo')
  end

  it 'quita la marca «requiere reconexión»' do
    2.times { channel.authorization_error! }
    expect(channel.reauthorization_required?).to be(true)

    reconnect
    expect(Channel::Whatsapp.find(channel.id).reauthorization_required?).to be(false)
  end
end
