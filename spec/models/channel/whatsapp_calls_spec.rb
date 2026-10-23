# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F2) — llamadas en la bandeja de WhatsApp.
RSpec.describe Channel::Whatsapp do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService, update_calling_status: true) }

  before { allow(channel).to receive(:provider_service).and_return(provider) }

  describe '#voice_enabled?' do
    it 'necesita la bandera de la cuenta y las llamadas activadas en la bandeja' do
      expect(channel.voice_enabled?).to be(false)

      channel.update_columns(provider_config: channel.provider_config.merge('calling_enabled' => true)) # rubocop:disable Rails/SkipsModelValidations
      expect(channel.voice_enabled?).to be(false)

      channel.account.enable_features!('whatsapp_calls')
      expect(channel.reload.voice_enabled?).to be(true)
    end

    it 'unoapi nunca tiene llamadas' do
      otro = create(:channel_whatsapp, provider: 'unoapi', sync_templates: false, validate_provider_config: false)
      expect(otro.voice_calling_supported?).to be(false)
    end
  end

  describe '#enable_voice_calling!' do
    before { channel.account.enable_features!('whatsapp_calls') }

    it 'activa en Meta y guarda el tipo; una bandeja configurada a mano queda con calls_webhook manual' do
      channel.enable_voice_calling!(direction: 'inbound')

      expect(provider).to have_received(:update_calling_status).with('ENABLED', icon: 'DEFAULT')
      expect(channel.reload.provider_config).to include('calling_enabled' => true, 'calling_direction' => 'inbound', 'calls_webhook' => 'manual')
      expect(channel.inbound_calls_allowed?).to be(true)
      expect(channel.outbound_calls_allowed?).to be(false)
    end

    it '«solo salientes» oculta el botón de llamar al cliente' do
      channel.enable_voice_calling!(direction: 'outbound')

      expect(provider).to have_received(:update_calling_status).with('ENABLED', icon: 'DISABLE_ALL')
      expect(channel.inbound_calls_allowed?).to be(false)
    end

    it 'con registro integrado suscribe el campo calls del webhook' do
      channel.update_columns(provider_config: channel.provider_config.merge('source' => 'embedded_signup')) # rubocop:disable Rails/SkipsModelValidations
      cliente = instance_double(Whatsapp::FacebookApiClient, subscribe_webhook: instance_double(HTTParty::Response, success?: true))
      allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(cliente)

      channel.enable_voice_calling!

      expect(cliente).to have_received(:subscribe_webhook).with(anything, anything, anything, anything, subscribed_fields: %w[messages calls])
      expect(channel.reload.provider_config['calls_webhook']).to eq('auto')
    end

    it 'si Meta no deja activar, no queda activada en Chatwoot' do
      allow(provider).to receive(:update_calling_status).and_raise('Límite de mensajería insuficiente')

      expect { channel.enable_voice_calling! }.to raise_error('Límite de mensajería insuficiente')
      expect(channel.reload.provider_config['calling_enabled']).to be_nil
    end

    it 'sin la bandera de la cuenta no se puede activar' do
      channel.account.disable_features!('whatsapp_calls')
      expect { channel.reload.enable_voice_calling! }.to raise_error(/no tiene activadas/)
    end
  end

  it 'apagar no se traba si Meta falla' do
    channel.update_columns(provider_config: channel.provider_config.merge('calling_enabled' => true)) # rubocop:disable Rails/SkipsModelValidations
    allow(provider).to receive(:update_calling_status).and_raise('Meta caído')

    channel.disable_voice_calling!

    expect(channel.reload.provider_config['calling_enabled']).to be(false)
  end
end
