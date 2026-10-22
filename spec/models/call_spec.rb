# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F1) — el modelo de una llamada de WhatsApp.
RSpec.describe Call do
  let(:call) { create(:call) }

  describe 'estados' do
    it 'arranca sonando y no es terminal' do
      expect(call).to be_ringing
      expect(call).not_to be_terminal
      expect(call.display_status).to eq('ringing')
    end

    it 'completed, no_answer, failed y rejected son terminales' do
      %w[completed no_answer failed rejected].each do |estado|
        call.update!(status: estado)
        expect(call).to be_terminal
      end
    end

    it 'no acepta un estado desconocido' do
      expect(call.update(status: 'colgada')).to be(false)
    end

    it 'muestra in-progress con guion y la dirección como inbound/outbound' do
      call.update!(status: 'in_progress')
      expect(call.display_status).to eq('in-progress')
      expect(call.direction_label).to eq('inbound')
    end
  end

  describe '#missed?' do
    it 'una entrante sin contestar es perdida' do
      call.update!(status: 'no_answer')
      expect(call).to be_missed
    end

    it 'una entrante que terminó sin agente es perdida (el cliente colgó al sonar)' do
      call.update!(status: 'completed')
      expect(call).to be_missed
    end

    it 'una entrante que tomó un agente no es perdida' do
      agente = create(:user, account: call.account)
      call.update!(status: 'completed', accepted_by_agent: agente)
      expect(call).not_to be_missed
    end

    it 'una saliente nunca es perdida' do
      saliente = create(:call, direction: :outgoing, status: 'no_answer')
      expect(saliente).not_to be_missed
    end
  end

  describe 'grabación' do
    it 'se decide al crearla: sin el ajuste en la bandeja, no se graba' do
      expect(call.recording_enabled?).to be(false)
    end

    it 'respeta lo que ya venga en meta' do
      grabada = create(:call, meta: { 'recording_enabled' => true })
      expect(grabada.recording_enabled?).to be(true)
    end
  end

  it 'merge_meta! agrega llaves sin pisar las que otro escribió' do
    call.merge_meta!('sdp_offer' => 'v=0 oferta')
    described_class.where(id: call.id).update_all("meta = meta || '{\"ice_servers\": []}'::jsonb") # rubocop:disable Rails/SkipsModelValidations
    call.merge_meta!('sdp_answer' => 'v=0 respuesta')

    expect(call.meta).to include('sdp_offer' => 'v=0 oferta', 'sdp_answer' => 'v=0 respuesta', 'ice_servers' => [])
  end

  it 'default_ice_servers trae el STUN de Google si no hay otro configurado' do
    expect(described_class.default_ice_servers).to eq([{ urls: ['stun:stun.l.google.com:19302'] }])
  end

  it 'push_event_data trae lo que necesita el dashboard' do
    expect(call.push_event_data).to include(id: call.id, provider: 'whatsapp', direction: 'inbound',
                                            status: 'ringing', conversation_id: call.conversation_id)
  end

  it 'la burbuja de la llamada es un mensaje voice_call con sus datos' do
    mensaje = create(:message, conversation: call.conversation, account: call.account, inbox: call.inbox,
                               content_type: :voice_call, content_attributes: { data: { 'call_id' => call.id } })
    expect(mensaje.reload).to be_voice_call
    expect(mensaje.data).to eq('call_id' => call.id)
  end

  it 'se borra junto con su conversación' do
    expect(call.conversation.calls).to eq([call])
  end

  # F8: los servicios hacen update!(status) y luego merge_meta! (reload) dentro del mismo candado
  describe 'al quedar perdida' do
    let(:call) { create(:call) }

    it 'encola sus acciones una vez, aunque después se recargue' do
      expect do
        call.with_lock do
          call.update!(status: 'no_answer')
          call.merge_meta!('ended_at' => 1)
        end
      end.to have_enqueued_job(Calls::MissedCallJob).with(call.id).exactly(:once)
    end

    it 'una contestada o una saliente no' do
      saliente = create(:call, direction: :outgoing)
      expect { saliente.update!(status: 'no_answer') }.not_to have_enqueued_job(Calls::MissedCallJob)
      expect { call.update!(status: 'in_progress', accepted_by_agent: create(:user)) }.not_to have_enqueued_job(Calls::MissedCallJob)
    end
  end
end
