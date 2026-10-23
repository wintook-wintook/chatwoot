# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F2) — el job de webhooks de llamadas.
RSpec.describe Webhooks::WhatsappCallEventsJob do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  # Los servicios llegan en F3: aquí se sustituyen por clases de prueba.
  let(:incoming) { Class.new { def initialize(**) = nil } }
  let(:reply) { Class.new { def initialize(**) = nil } }
  let(:servicio) { Class.new { def perform = true }.new }

  def payload(field:, value:)
    { object: 'whatsapp_business_account',
      entry: [{ changes: [{ field: field, value: { metadata: { display_phone_number: channel.phone_number.delete('+'),
                                                               phone_number_id: channel.provider_config['phone_number_id'] } }.merge(value) }] }] }
  end

  before do
    stub_const('Whatsapp::IncomingCallService', incoming)
    stub_const('Whatsapp::CallPermissionReplyService', reply)
    allow(incoming).to receive(:new).and_return(servicio)
    allow(reply).to receive(:new).and_return(servicio)
  end

  it 'va a la cola critical' do
    expect(described_class.new.queue_name).to eq('critical')
  end

  it 'reconoce lo que es de llamadas' do
    expect(described_class.handles?(payload(field: 'calls', value: {}).with_indifferent_access)).to be(true)
    respuesta = payload(field: 'messages', value: { messages: [{ interactive: { type: 'call_permission_reply' } }] })
    expect(described_class.handles?(respuesta.with_indifferent_access)).to be(true)
    expect(described_class.handles?(payload(field: 'messages', value: { messages: [{ type: 'text' }] }).with_indifferent_access)).to be(false)
  end

  context 'when las llamadas están activadas' do
    before do
      channel.account.enable_features!('whatsapp_calls')
      channel.update_columns(provider_config: channel.provider_config.merge('calling_enabled' => true)) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'manda cada evento y cada estado de llamada al servicio de llamadas' do
      described_class.perform_now(payload(field: 'calls', value: {
                                            calls: [{ id: 'wacid.1', event: 'connect' }],
                                            statuses: [{ id: 'wacid.1', type: 'call', status: 'ACCEPTED' }, { id: 'x', type: 'message' }]
                                          }))

      expect(incoming).to have_received(:new).with(inbox: channel.inbox, params: hash_including(calls: [hash_including(id: 'wacid.1')]))
      expect(incoming).to have_received(:new).with(inbox: channel.inbox, params: { statuses: [hash_including(status: 'ACCEPTED')] })
      expect(incoming).to have_received(:new).twice
    end

    it 'manda la respuesta al permiso a su servicio' do
      described_class.perform_now(payload(field: 'messages', value: { messages: [{ interactive: { type: 'call_permission_reply' } }] }))

      expect(reply).to have_received(:new)
      expect(incoming).not_to have_received(:new)
    end
  end

  it 'con las llamadas apagadas no hace nada' do
    described_class.perform_now(payload(field: 'calls', value: { calls: [{ id: 'wacid.1', event: 'connect' }] }))

    expect(incoming).not_to have_received(:new)
  end
end
