# frozen_string_literal: true

require 'rails_helper'

# diag/waba F1 — diagnóstico de la bandeja con Meta simulado (solo GET).
RSpec.describe Whatsapp::HealthCheckService do
  let(:account) { create(:account) }
  let(:channel) do
    ch = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    # la fábrica pone su propia configuración al crear: se fija después
    ch.update_column(:provider_config, { 'api_key' => 'tok', 'phone_number_id' => 'ph1', 'business_account_id' => 'waba1' }) # rubocop:disable Rails/SkipsModelValidations
    ch
  end
  let(:here) { "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/webhooks/whatsapp" }
  let(:inbox) { channel.inbox }
  let(:graph) { 'https://graph.facebook.com/v22.0' }

  around { |example| I18n.with_locale(:es) { example.run } }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_EMBEDDED_FACEBOOK_APP_ID', '').and_return('app1')
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET', '').and_return('secret')
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_EMBEDDED_FACEBOOK_API_VERSION', 'v22.0').and_return('v22.0')
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([{ 'queues' => %w[high low] }])
    stub_meta
  end

  def json(body, status = 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def stub_meta(app_ok: true, token_ok: true, subscribed: true, callback: nil, number: {})
    stub_app_and_token(app_ok, token_ok)
    apps = subscribed ? [{ whatsapp_business_api_data: { id: 'app1', name: 'Nuestra' } }] : [{ whatsapp_business_api_data: { id: 'otra' } }]
    stub_request(:get, %r{#{graph}/waba1/subscribed_apps}).to_return(json(data: apps))
    stub_request(:get, %r{#{graph}/app1/subscriptions})
      .to_return(json(data: [{ object: 'whatsapp_business_account', callback_url: callback || here }]))
    phone = { status: 'CONNECTED', quality_rating: 'GREEN', name_status: 'APPROVED', verified_name: 'Kontrolya', messaging_limit_tier: 'TIER_1K' }
    stub_request(:get, %r{#{graph}/ph1\?}).to_return(json(phone.merge(number)))
    stub_request(:get, %r{#{graph}/waba1\?}).to_return(json(account_review_status: 'APPROVED'))
  end

  def stub_app_and_token(app_ok, token_ok)
    stub_request(:get, %r{#{graph}/oauth/access_token}).to_return(app_ok ? json(access_token: 'app|tok') : json({ error: { code: 1 } }, 400))
    stub_request(:get, %r{#{graph}/me\?}).to_return(token_ok ? json(id: '1', name: 'x') : json({ error: { code: 190 } }, 401))
    scopes = %w[whatsapp_business_messaging whatsapp_business_management]
    stub_request(:get, %r{#{graph}/debug_token}).to_return(json(data: { expires_at: 0, scopes: scopes }))
  end

  def checks
    described_class.new(inbox).perform[:checks].index_by { |c| c[:key] }
  end

  it 'bandeja sana: todo en verde' do
    inbox.messages.create!(account: account, conversation: create(:conversation, inbox: inbox, account: account),
                           message_type: :incoming, content: 'hola')
    result = checks
    expect(result.values.pluck(:status).uniq).to eq(['ok'])
    expect(result['token'][:detail]).to eq('Es permanente.')
    expect(result['limit'][:title]).to include('1 000')
    expect(result['number'][:title]).to include('alta')
  end

  it 'app del sistema mal configurada: lo dice y no truena lo demás' do
    stub_meta(app_ok: false)
    result = checks
    expect(result['app'][:status]).to eq('fail')
    expect(result['token']).to include(status: 'ok')
    expect(result['token'][:detail]).to include('mal configurada')
    expect(result['webhook'][:status]).to eq('warn')
  end

  it 'token vencido: falla con «reconectar» y lo de Meta queda «no se pudo revisar»' do
    stub_meta(token_ok: false)
    result = checks
    expect(result['token']).to include(status: 'fail', action: 'reconnect')
    expect(result['webhook'][:status]).to eq('unknown')
    expect(result['number'][:status]).to eq('unknown')
  end

  it 'sin nuestra app suscrita: «Suscribir ahora»' do
    stub_meta(subscribed: false)
    expect(checks['webhook']).to include(status: 'fail', action: 'subscribe')
  end

  it 'Meta manda los mensajes a otro servidor' do
    stub_meta(callback: 'https://app.otro.com/webhooks/whatsapp')
    expect(checks['webhook']).to include(status: 'fail')
    expect(checks['webhook'][:detail]).to include('app.otro.com')
  end

  it 'número: nombre rechazado y calidad baja' do
    stub_meta(number: { name_status: 'DECLINED', quality_rating: 'RED' })
    result = checks
    expect(result['display_name']).to include(status: 'warn', action: 'open_meta')
    expect(result['number'][:status]).to eq('fail')
  end

  it 'envíos fallidos agrupados y traducidos; nunca recibió nada' do
    conversation = create(:conversation, inbox: inbox, account: account)
    2.times do
      inbox.messages.create!(account: account, conversation: conversation, message_type: :outgoing, content: 'x',
                             status: :failed, content_attributes: { external_error: '131047: Re-engagement message' })
    end
    inbox.messages.create!(account: account, conversation: conversation, message_type: :outgoing, content: 'y')
    result = checks
    expect(result['failed']).to include(status: 'warn')
    expect(result['failed'][:lines]).to eq(['2 · Pasaron más de 24 h desde el último mensaje del cliente: usa una plantilla.'])
    expect(result['last_incoming'][:title]).to eq('Esta bandeja nunca ha recibido mensajes')
  end

  it 'nadie atiende la cola de WhatsApp' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([{ 'queues' => %w[default] }])
    expect(checks['queue']).to include(status: 'fail')
  end

  it 'marca de reconexión' do
    allow(channel).to receive(:reauthorization_required?).and_return(true)
    allow(inbox).to receive(:channel).and_return(channel)
    expect(checks['reauthorization']).to include(status: 'fail', action: 'reconnect')
  end

  it 'Meta no responde: esa revisión sale «no se pudo», no truena' do
    stub_request(:get, %r{#{graph}/ph1\?}).to_timeout
    expect(checks['number'][:status]).to eq('unknown')
  end
end
