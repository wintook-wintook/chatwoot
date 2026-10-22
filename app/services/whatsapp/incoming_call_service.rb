# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — EVENTOS DE LLAMADA QUE MANDA META
# ================================================================================
# Lo llama Webhooks::WhatsappCallEventsJob con UN evento a la vez y bajo el candado de
# esa llamada. Portado de la v4.19 (enterprise/app/services/whatsapp/incoming_call_service.rb).
#
#   calls[] event=connect, sdp_type=offer   el cliente llama → nueva llamada que suena
#   calls[] event=connect, sdp_type=answer  nuestra saliente: el túnel WebRTC está listo
#                                           (~20 s ANTES de que contesten: no es «contestó»)
#   statuses[] ACCEPTED                     nuestra saliente: el cliente contestó de verdad
#   calls[] event=terminate                 terminó (con duración y motivo)
#
# Meta no garantiza el orden: un terminate puede llegar antes que su connect. Se guarda
# 60 s como «lápida» en Redis y el connect, al llegar, crea la llamada ya terminada (y no
# hace sonar a nadie).
# ================================================================================
class Whatsapp::IncomingCallService
  pattr_initialize [:inbox!, :params!]

  TERMINATE_TOMBSTONE_TTL = 60
  # Un terminate con cualquiera de estos motivos es falla, aunque haya estado en curso.
  FAILURE_REASONS = %w[failed error rejected busy invalid_offer cancelled].freeze

  def perform
    return unless inbox.channel.voice_enabled?

    Array(params[:calls]).each { |evento| handle_event(evento.with_indifferent_access) }
    Array(params[:statuses]).each { |estado| handle_status(estado.with_indifferent_access) }
  end

  private

  def handle_event(evento)
    case evento[:event]
    when 'connect' then handle_connect(evento)
    when 'terminate' then handle_terminate(evento)
    else Rails.logger.warn "[WHATSAPP CALL] evento desconocido: #{evento[:event]}"
    end
  end

  def handle_status(estado)
    return unless estado[:type] == 'call' && estado[:status] == 'ACCEPTED'

    call = Call.whatsapp.find_by(provider_call_id: estado[:id])
    mark_outbound_accepted(call, estado) if call&.outgoing?
  end

  def mark_outbound_accepted(call, estado)
    call.with_lock do
      next if call.in_progress? || call.terminal?

      started_at = estado[:timestamp].present? ? Time.zone.at(estado[:timestamp].to_i) : Time.current
      update_call!(call, 'in_progress', started_at: started_at)
      Calls::Broadcaster.new(call: call).to_caller(:outbound_accepted)
    end
  end

  def handle_connect(evento)
    call = Call.whatsapp.find_by(provider_call_id: evento[:id])
    return accept_outbound(call, evento) if call&.outgoing?
    return if call # reintento de un connect entrante que ya existe

    return create_inbound(evento) if evento.dig(:session, :sdp_type).to_s.casecmp('offer').zero?

    # Un answer sin llamada nuestra: Meta le ganó a nuestro Call.create! de la saliente.
    Rails.logger.warn "[WHATSAPP CALL] connect de saliente desconocida #{evento[:id]}; se ignora"
  end

  def create_inbound(evento)
    unless inbox.channel.inbound_calls_allowed?
      Rails.logger.info "[WHATSAPP CALL] bandeja #{inbox.id} sin entrantes: se rechaza #{evento[:id]}"
      inbox.channel.calls_provider.reject_call(evento[:id])
      return
    end

    call = build_inbound(evento)
    return if call.terminal? # colgó antes de que llegara el connect: no se hace sonar

    update_conversation(call)
    Calls::Broadcaster.new(call: call).ring!(**ring_payload(call))
  end

  def ring_payload(call)
    contacto = call.contact
    { sdp_offer: call.sdp_offer, ice_servers: call.ice_servers, recording_enabled: call.recording_enabled?,
      caller: { name: contacto.name, phone: contacto.phone_number, avatar: contacto.avatar_url } }
  end

  def build_inbound(evento)
    ActiveRecord::Base.transaction do
      call = Voice::InboundCallBuilder.new(
        inbox: inbox, call_id: evento[:id], wa_id: caller_wa_id(evento), contact_name: caller_name(evento),
        extra_meta: { 'sdp_offer' => evento.dig(:session, :sdp), 'ice_servers' => Call.default_ice_servers }
      ).perform!
      lapida = consume_tombstone(evento[:id])
      finalize(call, lapida['duration'], lapida['terminate_reason']) if lapida
      call
    end
  end

  # `connect` de nuestra saliente: se aplica el SDP de Meta para completar el saludo
  # WebRTC mientras suena; sigue `ringing` hasta ACCEPTED. El SDP guardado evita
  # aplicarlo dos veces.
  def accept_outbound(call, evento)
    call.with_lock do
      next if call.terminal? || call.sdp_answer.present?

      # setup:active fijo: así el navegador no renegocia cuando Meta repite actpass.
      sdp_answer = evento.dig(:session, :sdp)&.gsub('a=setup:actpass', 'a=setup:active')
      call.merge_meta!('sdp_answer' => sdp_answer)
      Calls::Broadcaster.new(call: call).to_caller(:outbound_connected, sdp_answer: sdp_answer)
    end
  end

  def handle_terminate(evento)
    call = Call.whatsapp.find_by(provider_call_id: evento[:id])
    return record_tombstone(evento) if call.nil?

    finalize(call, evento[:duration], evento[:terminate_reason])
  end

  def finalize(call, duration, reason)
    call.with_lock do
      # Un reintento del terminate no debe recalcular un estado ya final.
      next if call.terminal?

      update_call!(call, terminal_status(call, duration.to_i, reason.to_s),
                   duration_seconds: duration&.to_i, end_reason: reason.to_s, ended_at: Time.zone.now.to_i)
      Calls::Broadcaster.new(call: call).to_ringers(:ended, status: call.display_status, duration_seconds: call.duration_seconds)
    end
  end

  def terminal_status(call, duration, reason)
    return 'failed' if FAILURE_REASONS.any? { |motivo| reason.include?(motivo) }

    contestada = call.in_progress? || duration.positive? || (call.incoming? && call.accepted_by_agent_id.present?)
    contestada ? 'completed' : 'no_answer'
  end

  def update_call!(call, status, ended_at: nil, **attrs)
    call.update!(status: status, **attrs)
    call.merge_meta!('ended_at' => ended_at) if ended_at
    Voice::CallMessageBuilder.new(call).update_status!(status: status, agent: call.accepted_by_agent,
                                                       duration_seconds: attrs[:duration_seconds])
    update_conversation(call)
  end

  def update_conversation(call)
    atributos = (call.conversation.additional_attributes || {}).merge('call_status' => call.display_status,
                                                                      'call_direction' => call.direction_label)
    call.conversation.update!(additional_attributes: atributos)
  end

  def caller_wa_id(evento)
    contacto = Array(params[:contacts]).first || {}
    (contacto[:wa_id] || contacto['wa_id'] || evento[:from]).to_s.delete('+')
  end

  def caller_name(evento)
    contacto = Array(params[:contacts]).first || {}
    contacto.dig(:profile, :name) || contacto.dig('profile', 'name') || evento[:from]
  end

  def record_tombstone(evento)
    ::Redis::Alfred.setex(tombstone_key(evento[:id]),
                          { 'duration' => evento[:duration], 'terminate_reason' => evento[:terminate_reason] }.to_json,
                          TERMINATE_TOMBSTONE_TTL)
    Rails.logger.info "[WHATSAPP CALL] terminate antes del connect de #{evento[:id]}: se guarda la lápida"
  end

  def consume_tombstone(call_id)
    raw = ::Redis::Alfred.get(tombstone_key(call_id))
    return if raw.blank?

    ::Redis::Alfred.delete(tombstone_key(call_id))
    JSON.parse(raw)
  end

  def tombstone_key(call_id)
    format(::Redis::Alfred::WHATSAPP_CALL_TERMINATE_TOMBSTONE, call_id: call_id)
  end
end
