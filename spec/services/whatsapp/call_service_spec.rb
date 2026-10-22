# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3) — contestar, rechazar y colgar.
RSpec.describe Whatsapp::CallService do
  let(:channel) { calling_channel }
  let(:agente) { create(:user, account: channel.account) }
  let(:otro) { create(:user, account: channel.account) }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox) }
  let(:call) do
    create(:call, account: channel.account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact)
  end

  before do
    stub_meta_calls
    allow(ActionCable.server).to receive(:broadcast)
    Voice::CallMessageBuilder.new(call).perform!.tap { |m| call.update!(message: m) }
  end

  describe '#accept' do
    it 'la pone en curso, la toma el agente y se queda con la conversación' do
      described_class.new(call: call, agent: agente, sdp_answer: 'v=0 answer').accept

      expect(call.reload).to have_attributes(status: 'in_progress', accepted_by_agent: agente, sdp_answer: 'v=0 answer')
      expect(conversation.reload.assignee).to eq(agente)
      expect(call.message.reload.content_attributes.dig('data', 'accepted_by', 'id')).to eq(agente.id)
    end

    it 'si otro ya contestó: AlreadyAccepted' do
      described_class.new(call: call, agent: otro, sdp_answer: 'v=0').accept
      expect { described_class.new(call: call.reload, agent: agente, sdp_answer: 'v=0').accept }
        .to raise_error(Voice::CallErrors::AlreadyAccepted)
    end

    it 'si el cliente ya colgó: CallAlreadyEnded' do
      call.update!(status: 'no_answer')
      expect { described_class.new(call: call, agent: agente, sdp_answer: 'v=0').accept }
        .to raise_error(Voice::CallErrors::CallAlreadyEnded)
    end

    it 'si Meta falla, la llamada sigue sonando' do
      stub_meta_calls(accept_call: false)
      expect { described_class.new(call: call, agent: agente, sdp_answer: 'v=0').accept }
        .to raise_error(Voice::CallErrors::CallFailed)
      expect(call.reload).to be_ringing
    end
  end

  it 'rechazar la deja rejected' do
    described_class.new(call: call, agent: agente).reject
    expect(call.reload).to have_attributes(status: 'rejected', end_reason: 'agent_rejected')
  end

  it 'colgar una en curso la deja completed con su duración' do
    call.update!(status: 'in_progress', started_at: 90.seconds.ago, accepted_by_agent: agente)

    described_class.new(call: call, agent: agente).terminate

    expect(call.reload.status).to eq('completed')
    expect(call.duration_seconds).to be_between(89, 92)
  end
end
