# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F8) — LLAMADAS QUE SE QUEDARON SONANDO
# ================================================================================
# Cada 30 s (config/schedule.yml). Una entrante que lleva más de 60 s sonando sin que
# nadie la tome se rechaza en Meta y queda «Perdida» (no_answer, ring_timeout): el timbre
# se quita en todas las pestañas y corren las acciones de llamada perdida.
# Una saliente la cuelga Meta sola; si su aviso no llegó, a los 3 min se da por perdida.
# Si Meta falla al colgar, la llamada se cierra igual aquí (queda en el log).
# ================================================================================
class Calls::RingingTimeoutJob < ApplicationJob
  queue_as :scheduled_jobs

  INCOMING_TIMEOUT = 60.seconds
  OUTGOING_TIMEOUT = 3.minutes

  def perform
    vencidas.find_each { |call| expire(call) }
  end

  private

  def vencidas
    Call.whatsapp.ringing.where(direction: :incoming).where(created_at: ...INCOMING_TIMEOUT.ago)
        .or(Call.whatsapp.ringing.where(direction: :outgoing).where(created_at: ...OUTGOING_TIMEOUT.ago))
  end

  def expire(call)
    call.with_lock do
      next unless call.ringing?

      avisar_a_meta(call)
      call.update!(status: 'no_answer', end_reason: 'ring_timeout')
      call.merge_meta!('ended_at' => Time.zone.now.to_i)
      Voice::CallMessageBuilder.new(call).update_status!(status: 'no_answer')
      conversation = call.conversation
      conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('call_status' => call.display_status))
      Calls::Broadcaster.new(call: call).to_ringers(:ended, status: call.display_status)
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP CALL] timeout de la llamada #{call.id}: #{e.class} #{e.message}"
  end

  def avisar_a_meta(call)
    metodo = call.incoming? ? :reject_call : :terminate_call
    call.inbox.channel.calls_provider.public_send(metodo, call.provider_call_id)
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] #{metodo} al vencer la llamada #{call.id}: #{e.message}"
  end
end
