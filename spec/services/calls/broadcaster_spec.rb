# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3) — a quién le suena una llamada (§4.3 del plan).
RSpec.describe Calls::Broadcaster do
  let(:channel) { calling_channel }
  let(:inbox) { channel.inbox }
  let(:asignado) { create(:user, account: inbox.account) }
  let(:otro) { create(:user, account: inbox.account) }
  let(:conversation) { create(:conversation, account: inbox.account, inbox: inbox, assignee: asignado) }
  let(:call) { create(:call, account: inbox.account, inbox: inbox, conversation: conversation, contact: conversation.contact) }

  def en_linea(*usuarios)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(usuarios.to_h { |u| [u.id.to_s, 'online'] })
  end

  before do
    [asignado, otro].each { |u| create(:inbox_member, inbox: inbox, user: u) }
    allow(ActionCable.server).to receive(:broadcast)
  end

  it 'si el asignado está en línea, le suena solo a él' do
    en_linea(asignado, otro)
    described_class.new(call: call).ring!
    expect(call.reload.ring_state['ring_recipient_ids']).to eq([asignado.id])
  end

  it 'si el asignado no está, suena a todos los en línea de la bandeja' do
    en_linea(otro)
    described_class.new(call: call).ring!
    expect(call.reload.ring_state['ring_recipient_ids']).to eq([otro.id])
  end

  it 'si nadie está en línea, suena a miembros y administradores' do
    en_linea
    described_class.new(call: call).ring!
    expect(call.reload.ring_state['ring_recipient_ids']).to include(asignado.id, otro.id)
  end

  it 'con «todos en línea» ignora al asignado' do
    channel.update_columns(provider_config: channel.provider_config.merge('ring_strategy' => 'all_online')) # rubocop:disable Rails/SkipsModelValidations
    en_linea(asignado, otro)
    described_class.new(call: call.reload).ring!
    expect(call.reload.ring_state['ring_recipient_ids']).to contain_exactly(asignado.id, otro.id)
  end

  it 'al contestar avisa a todos a los que sonó, para quitar el timbre' do
    channel.update_columns(provider_config: channel.provider_config.merge('ring_strategy' => 'all_online')) # rubocop:disable Rails/SkipsModelValidations
    en_linea(asignado, otro)
    described_class.new(call: call.reload).ring!
    call.update!(accepted_by_agent: otro)

    described_class.new(call: call).to_ringers(:accepted)

    [asignado, otro].each do |u|
      expect(ActionCable.server).to have_received(:broadcast).with(u.pubsub_token, hash_including(event: 'voice_call.accepted'))
    end
  end
end
