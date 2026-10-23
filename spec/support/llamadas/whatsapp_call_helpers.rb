# frozen_string_literal: true

# diag/llamadas_whatsapp (F3) — una bandeja whatsapp_cloud con llamadas activadas.
module WhatsappCallHelpers
  def calling_channel(direction: 'both', account: create(:account))
    account.enable_features!('whatsapp_calls')
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    channel.update_columns(provider_config: channel.provider_config.merge('calling_enabled' => true, 'calling_direction' => direction)) # rubocop:disable Rails/SkipsModelValidations
    channel.reload
  end

  # Meta siempre dice que sí, salvo lo que la prueba cambie.
  def stub_meta_calls(**overrides)
    servicio = Whatsapp::Providers::WhatsappCloudService
    { pre_accept_call: true, accept_call: true, reject_call: true, terminate_call: true }.merge(overrides).each do |metodo, valor|
      allow_any_instance_of(servicio).to receive(metodo).and_return(valor) # rubocop:disable RSpec/AnyInstance
    end
  end

  def connect_offer(call_id, wa_id: '5215512345678', name: 'Juan Pérez')
    { calls: [{ id: call_id, event: 'connect', from: wa_id, session: { sdp_type: 'offer', sdp: 'v=0 offer' } }],
      contacts: [{ wa_id: wa_id, profile: { name: name } }] }
  end
end

RSpec.configure { |config| config.include WhatsappCallHelpers }
