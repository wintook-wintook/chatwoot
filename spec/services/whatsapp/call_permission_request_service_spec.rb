# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3) — pedir permiso (límites de Meta) y la respuesta del cliente.
RSpec.describe Whatsapp::CallPermissionRequestService do
  let(:channel) { calling_channel }
  let(:agente) { create(:user, account: channel.account) }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox) }

  def pedir
    Whatsapp::CallPermissionRequestService.new(conversation: conversation.reload, recipient: '5215512345678', requester: agente).perform
  end

  before do
    allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService) # rubocop:disable RSpec/AnyInstance
      .to receive(:send_call_permission_request).and_return({ 'messages' => [{ 'id' => 'wamid.req' }] })
  end

  it 'la primera vez la manda y guarda el wamid y quién la pidió' do
    expect(pedir).to eq(status: 'permission_requested')
    expect(conversation.reload.additional_attributes).to include('call_permission_request_message_id' => 'wamid.req',
                                                                 'call_permission_requested_by' => agente.id)
  end

  it 'máximo 1 al día: la segunda del mismo día dice cuándo se podrá' do
    pedir
    resultado = pedir
    expect(resultado[:status]).to eq('permission_limit')
    expect(Time.zone.parse(resultado[:next_allowed_at])).to be_within(1.minute).of(24.hours.from_now)
  end

  it 'máximo 2 por semana' do
    travel_to(3.days.ago) { pedir }
    travel_to(2.days.ago) { pedir }
    expect(pedir[:status]).to eq('permission_limit')
  end

  it 'si Meta falla devuelve failed' do
    allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService).to receive(:send_call_permission_request).and_return(nil) # rubocop:disable RSpec/AnyInstance
    expect(pedir).to eq(status: 'failed')
  end

  describe Whatsapp::CallPermissionReplyService do
    def respuesta(response)
      { entry: [{ changes: [{ value: { messages: [{ from: '5215512345678', context: { id: 'wamid.req' },
                                                    interactive: { type: 'call_permission_reply',
                                                                   call_permission_reply: { response: response } } }] } }] }] }
        .with_indifferent_access
    end

    before do
      allow(ActionCable.server).to receive(:broadcast)
      pedir
    end

    it 'si acepta avisa a quien la pidió y quita lo pendiente' do
      described_class.new(inbox: channel.inbox, params: respuesta('accept')).perform

      expect(ActionCable.server).to have_received(:broadcast)
        .with(agente.pubsub_token, hash_including(event: 'voice_call.permission_granted'))
      expect(conversation.reload.additional_attributes).not_to have_key('call_permission_request_message_id')
    end

    it 'si rechaza no hace nada' do
      described_class.new(inbox: channel.inbox, params: respuesta('reject')).perform
      expect(ActionCable.server).not_to have_received(:broadcast)
    end
  end
end
