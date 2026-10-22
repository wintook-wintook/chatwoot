# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — LO QUE HACE EL AGENTE CON UNA LLAMADA
# ================================================================================
#   accept     (entrante) manda a Meta pre_accept + accept con el SDP del navegador
#   reject     (entrante que suena) la rechaza en Meta
#   terminate  cuelga (en curso o sonando)
#
# Todo bajo el candado de la fila: dos agentes contestando a la vez → uno gana y el otro
# recibe AlreadyAccepted (409); contestar una que el cliente ya colgó → CallAlreadyEnded.
# Si Meta falla, se levanta antes de tocar el estado local: no se marca terminada una
# llamada que Meta sigue teniendo viva.
# Portado de la v4.19 (enterprise/app/services/whatsapp/call_service.rb).
# ================================================================================
class Whatsapp::CallService
  pattr_initialize [:call!, :agent!, :sdp_answer]

  def accept
    raise Voice::CallErrors::CallFailed, 'Falta el sdp_answer' if sdp_answer.blank?

    call.with_lock do
      ensure_ringing!
      provider!(:pre_accept_call, sdp_answer)
      provider!(:accept_call, sdp_answer)
      call.update!(status: 'in_progress', accepted_by_agent: agent, started_at: Time.current)
      call.merge_meta!('sdp_answer' => sdp_answer)
      message_status!('in_progress')
      claim_conversation
      broadcaster.to_ringers(:accepted, accepted_by_agent_id: agent.id)
    end
    call
  end

  def reject
    call.with_lock do
      next if call.terminal? || call.in_progress?

      provider!(:reject_call)
      call.update!(accepted_by_agent: agent) if call.accepted_by_agent_id.nil?
      finalize('rejected', end_reason: 'agent_rejected')
    end
    call
  end

  def terminate
    call.with_lock do
      next if call.terminal?

      provider!(:terminate_call)
      if call.in_progress?
        finalize('completed', end_reason: 'agent_hangup',
                              duration_seconds: call.started_at ? (Time.current - call.started_at).to_i : nil)
      else
        finalize('no_answer', end_reason: 'agent_hangup')
      end
    end
    call
  end

  private

  # En este orden: puede haber contestado otro, o el cliente pudo colgar mientras sonaba.
  def ensure_ringing!
    raise Voice::CallErrors::AlreadyAccepted, 'Otro agente ya contestó' if call.in_progress?
    raise Voice::CallErrors::CallAlreadyEnded, 'La llamada ya terminó' if call.terminal?
    raise Voice::CallErrors::NotRinging, 'La llamada no está sonando' unless call.ringing?
  end

  def provider!(metodo, *)
    ok = call.inbox.channel.provider_service.public_send(metodo, call.provider_call_id, *)
    raise Voice::CallErrors::CallFailed, "Meta #{metodo} falló" unless ok
  rescue Voice::CallErrors::CallFailed
    raise
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP CALL] #{metodo} falló: #{e.class} #{e.message}"
    raise Voice::CallErrors::CallFailed, "Meta #{metodo} falló"
  end

  def finalize(status, **attrs)
    call.update!(status: status, **attrs)
    call.merge_meta!('ended_at' => Time.zone.now.to_i)
    message_status!(status, duration_seconds: attrs[:duration_seconds])
    conversation_call_status!
    broadcaster.to_ringers(:ended, status: call.display_status, duration_seconds: call.duration_seconds)
  end

  def message_status!(status, duration_seconds: nil)
    Voice::CallMessageBuilder.new(call).update_status!(status: status, agent: agent, duration_seconds: duration_seconds)
  end

  # Quien contesta se queda con la conversación si nadie la tenía (D5).
  def claim_conversation
    conversation = call.conversation
    attrs = { additional_attributes: (conversation.additional_attributes || {}).merge('call_status' => call.display_status) }
    attrs[:assignee] = agent if conversation.assignee_id.nil?
    conversation.update!(attrs)
  end

  def conversation_call_status!
    conversation = call.conversation
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge('call_status' => call.display_status))
  end

  def broadcaster
    @broadcaster ||= Calls::Broadcaster.new(call: call)
  end
end
