# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F7, P1) — el aviso al cliente de que la llamada se graba.
RSpec.describe Voice::RecordingNoticeService do
  let(:channel) { calling_channel }
  let(:agente) { create(:user, account: channel.account) }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox) }
  let(:grabar) { true }
  let(:call) do
    create(:call, account: channel.account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact,
                  meta: { 'recording_enabled' => grabar })
  end

  before do
    stub_meta_calls
    allow(ActionCable.server).to receive(:broadcast)
    Voice::CallMessageBuilder.new(call).perform!.tap { |m| call.update!(message: m) }
  end

  def avisos
    conversation.messages.where(message_type: :outgoing, content_type: :text)
  end

  it 'al contestar una que se graba le manda el aviso al cliente, una sola vez' do
    Whatsapp::CallService.new(call: call, agent: agente, sdp_answer: 'v=0').accept
    described_class.new(call: call.reload, agent: agente).perform

    expect(avisos.count).to eq(1)
    expect(avisos.first).to have_attributes(content: I18n.t('conversations.messages.whatsapp.call_recording_notice'), sender: agente)
  end

  it 'usa el texto de la bandeja si lo tiene' do
    channel.update_columns(provider_config: channel.provider_config.merge('recording_notice' => 'Grabamos esta llamada.')) # rubocop:disable Rails/SkipsModelValidations
    Whatsapp::CallService.new(call: call, agent: agente, sdp_answer: 'v=0').accept

    expect(avisos.pluck(:content)).to eq(['Grabamos esta llamada.'])
  end

  describe 'sin grabación' do
    let(:grabar) { false }

    it 'no manda nada' do
      Whatsapp::CallService.new(call: call, agent: agente, sdp_answer: 'v=0').accept
      expect(avisos).to be_empty
    end
  end

  it 'si no se puede mandar, la llamada sigue en curso' do
    allow(Message).to receive(:create!).and_call_original
    allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:create!).and_raise(StandardError, 'ventana cerrada') # rubocop:disable RSpec/AnyInstance
    call.update!(status: 'in_progress')

    expect { described_class.new(call: call, agent: agente).perform }.not_to raise_error
    expect(call.reload.status).to eq('in_progress')
  end
end
