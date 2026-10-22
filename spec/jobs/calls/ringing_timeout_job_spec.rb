# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F8) — las que se quedaron sonando quedan «Perdida».
RSpec.describe Calls::RingingTimeoutJob do
  let(:channel) { calling_channel }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox) }

  def llamada(hace:, direction: :incoming, id: SecureRandom.hex(4))
    create(:call, account: channel.account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact,
                  direction: direction, provider_call_id: "wacid.#{id}", created_at: hace.ago).tap do |call|
      call.update!(message: Voice::CallMessageBuilder.new(call).perform!)
    end
  end

  before do
    stub_meta_calls
    allow(ActionCable.server).to receive(:broadcast)
  end

  it 'una entrante que lleva más de 60 s sonando: la rechaza en Meta, queda perdida y corren sus acciones' do
    vieja = llamada(hace: 61.seconds)
    nueva = llamada(hace: 20.seconds)

    expect { described_class.perform_now }.to have_enqueued_job(Calls::MissedCallJob).with(vieja.id)

    expect(vieja.reload).to have_attributes(status: 'no_answer', end_reason: 'ring_timeout')
    expect(vieja.message.reload.content_attributes.dig('data', 'status')).to eq('no-answer')
    expect(conversation.reload.additional_attributes['call_status']).to eq('no-answer')
    expect(nueva.reload.status).to eq('ringing')
  end

  it 'una saliente se espera 3 min (la cuelga Meta) y no es «perdida»' do
    saliente = llamada(hace: 2.minutes, direction: :outgoing)
    described_class.perform_now
    expect(saliente.reload.status).to eq('ringing')

    saliente.update_columns(created_at: 4.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
    expect { described_class.perform_now }.not_to have_enqueued_job(Calls::MissedCallJob)
    expect(saliente.reload.status).to eq('no_answer')
  end

  it 'si Meta falla al colgar, se cierra igual' do
    stub_meta_calls(reject_call: nil)
    allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService).to receive(:reject_call).and_raise(StandardError) # rubocop:disable RSpec/AnyInstance
    vieja = llamada(hace: 2.minutes)

    described_class.perform_now
    expect(vieja.reload.status).to eq('no_answer')
  end
end
