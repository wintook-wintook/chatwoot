# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3) — eventos de llamada que manda Meta.
RSpec.describe Whatsapp::IncomingCallService do
  let(:channel) { calling_channel }
  let(:inbox) { channel.inbox }
  let(:agente) { create(:user, account: channel.account) }

  def procesar(params)
    described_class.new(inbox: inbox, params: params.with_indifferent_access).perform
  end

  before do
    stub_meta_calls
    allow(ActionCable.server).to receive(:broadcast)
    create(:inbox_member, inbox: inbox, user: agente)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agente.id.to_s => 'online' })
  end

  describe 'llamada entrante' do
    it 'crea la llamada sonando, con contacto, conversación y burbuja, y la hace sonar' do
      procesar(connect_offer('wacid.1'))

      call = Call.find_by!(provider_call_id: 'wacid.1')
      expect(call).to have_attributes(status: 'ringing', direction: 'incoming', sdp_offer: 'v=0 offer')
      expect(call.contact).to have_attributes(name: 'Juan Pérez', phone_number: '+5215512345678')
      expect(call.message).to have_attributes(content_type: 'voice_call', message_type: 'incoming')
      expect(call.ring_state['ring_recipient_ids']).to eq([agente.id])
      expect(ActionCable.server).to have_received(:broadcast)
        .with(agente.pubsub_token, hash_including(event: 'voice_call.incoming', data: hash_including(sdp_offer: 'v=0 offer')))
    end

    it 'el aviso trae el tono de la bandeja (una pestaña vieja no lo tiene al día)' do
      inbox.channel.update_columns(provider_config: inbox.channel.provider_config.merge('ringtone' => 'digital')) # rubocop:disable Rails/SkipsModelValidations
      procesar(connect_offer('wacid.tono'))

      expect(ActionCable.server).to have_received(:broadcast)
        .with(agente.pubsub_token, hash_including(event: 'voice_call.incoming', data: hash_including(ringtone: 'digital')))
    end

    it 'cae en la conversación abierta del contacto, igual que un mensaje' do
      contact_inbox = ContactInboxWithContactBuilder.new(source_id: '5215512345678', inbox: inbox,
                                                         contact_attributes: { name: 'Juan' }).perform
      abierta = create(:conversation, account: inbox.account, inbox: inbox, contact: contact_inbox.contact, contact_inbox: contact_inbox)

      procesar(connect_offer('wacid.2'))

      expect(Call.find_by!(provider_call_id: 'wacid.2').conversation).to eq(abierta)
    end

    it 'un reintento del mismo connect no crea otra llamada' do
      2.times { procesar(connect_offer('wacid.3')) }
      expect(Call.where(provider_call_id: 'wacid.3').count).to eq(1)
    end

    it 'en una bandeja de solo salientes se rechaza en Meta y no se crea' do
      channel.update_columns(provider_config: channel.provider_config.merge('calling_direction' => 'outbound')) # rubocop:disable Rails/SkipsModelValidations

      procesar(connect_offer('wacid.4'))

      expect(Call.find_by(provider_call_id: 'wacid.4')).to be_nil
    end

    it 'sin la bandera de la cuenta no hace nada' do
      channel.account.disable_features!('whatsapp_calls')
      procesar(connect_offer('wacid.5'))
      expect(Call.find_by(provider_call_id: 'wacid.5')).to be_nil
    end
  end

  describe 'terminar' do
    it 'sin contestar queda no_answer, con la burbuja y el aviso de fin' do
      procesar(connect_offer('wacid.6'))
      procesar(calls: [{ id: 'wacid.6', event: 'terminate', duration: 0, terminate_reason: 'completed' }])

      call = Call.find_by!(provider_call_id: 'wacid.6')
      expect(call).to have_attributes(status: 'no_answer')
      expect(call).to be_missed
      expect(call.message.reload.content_attributes.dig('data', 'status')).to eq('no-answer')
      expect(ActionCable.server).to have_received(:broadcast).with(agente.pubsub_token, hash_including(event: 'voice_call.ended'))
    end

    it 'con motivo de error queda failed' do
      procesar(connect_offer('wacid.7'))
      procesar(calls: [{ id: 'wacid.7', event: 'terminate', terminate_reason: 'failed' }])
      expect(Call.find_by!(provider_call_id: 'wacid.7').status).to eq('failed')
    end

    it 'un reintento del terminate no cambia el estado final' do
      procesar(connect_offer('wacid.8'))
      call = Call.find_by!(provider_call_id: 'wacid.8')
      call.update!(status: 'completed', duration_seconds: 40)

      procesar(calls: [{ id: 'wacid.8', event: 'terminate', duration: 0 }])

      expect(call.reload).to have_attributes(status: 'completed', duration_seconds: 40)
    end

    it 'si el terminate llega antes que el connect, la llamada nace terminada y no suena' do
      procesar(calls: [{ id: 'wacid.9', event: 'terminate', duration: 0, terminate_reason: 'completed' }])
      procesar(connect_offer('wacid.9'))

      expect(Call.find_by!(provider_call_id: 'wacid.9').status).to eq('no_answer')
      expect(ActionCable.server).not_to have_received(:broadcast).with(anything, hash_including(event: 'voice_call.incoming'))
    end
  end

  describe 'llamada saliente' do
    let(:conversation) { create(:conversation, account: inbox.account, inbox: inbox) }
    let!(:call) do
      create(:call, account: inbox.account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                    provider_call_id: 'wacid.out', direction: :outgoing, accepted_by_agent: agente)
    end

    it 'el connect aplica el SDP de Meta (setup:active) pero sigue sonando' do
      procesar(calls: [{ id: 'wacid.out', event: 'connect', session: { sdp_type: 'answer', sdp: "v=0\na=setup:actpass" } }])

      expect(call.reload).to have_attributes(status: 'ringing', sdp_answer: "v=0\na=setup:active")
      expect(ActionCable.server).to have_received(:broadcast).with(agente.pubsub_token, hash_including(event: 'voice_call.outbound_connected'))
    end

    it 'ACCEPTED es cuando el cliente contestó de verdad' do
      procesar(statuses: [{ id: 'wacid.out', type: 'call', status: 'ACCEPTED', timestamp: 1_760_000_000 }])

      expect(call.reload).to have_attributes(status: 'in_progress', started_at: Time.zone.at(1_760_000_000))
    end

    # F7 (P1): en la saliente el aviso sale cuando el cliente contesta
    it 'si se graba, al contestar el cliente se le manda el aviso' do
      call.merge_meta!('recording_enabled' => true)
      procesar(statuses: [{ id: 'wacid.out', type: 'call', status: 'ACCEPTED', timestamp: 1_760_000_000 }])

      expect(conversation.messages.where(content_type: :text, message_type: :outgoing).pluck(:content))
        .to eq([I18n.t('conversations.messages.whatsapp.call_recording_notice')])
    end
  end
end
