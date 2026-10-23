# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F4) — META SIMULADA PARA PROBAR LLAMADAS SIN NÚMERO
# ================================================================================
# Solo con WHATSAPP_CALLS_SIMULATOR=true y en development/test (en producción no existe:
# `enabled?` es false). Channel::Whatsapp#calls_provider la devuelve en lugar de la
# Calling API real; tiene los mismos métodos que WhatsappCloudCalls.
#
#   El «cliente» es la página «Cliente simulado» del dashboard (admin). Se hablan así:
#   - de aquí a la página: señales en Redis por bandeja + wa_id (la página las recoge
#     cada segundo): answer, ended, incoming (el negocio llama), permission_request
#   - de la página a aquí: WhatsappCallSimulatorController arma el MISMO webhook que
#     mandaría Meta y lo encola en Webhooks::WhatsappCallEventsJob (camino real)
#
# El audio es WebRTC real entre la pestaña del agente y la del cliente simulado.
# Plan: docs/llamadas_whatsapp_plan.md §4.6
# ================================================================================
class Whatsapp::Providers::CallsSimulator
  SIGNALS_KEY = 'WA_CALL_SIMULATOR::%<inbox_id>s::%<wa_id>s'
  CALLS_KEY = 'WA_CALL_SIMULATOR::CALL::%<call_id>s'
  PERMISSION_KEY = 'WA_CALL_SIMULATOR::PERMISSION::%<inbox_id>s::%<wa_id>s'
  TTL = 2.hours

  pattr_initialize [:whatsapp_channel!]

  def self.enabled?
    (Rails.env.development? || Rails.env.test?) && ENV.fetch('WHATSAPP_CALLS_SIMULATOR', 'false') == 'true'
  end

  # ── Lo mismo que WhatsappCloudCalls ─────────────────────────────────────────
  def pre_accept_call(_call_id, _sdp_answer)
    true
  end

  # El agente contestó: la página aplica este answer y empieza el audio.
  def accept_call(call_id, sdp_answer)
    signal_for_call(call_id, type: 'answer', call_id: call_id, sdp: sdp_answer)
    true
  end

  def reject_call(call_id)
    signal_for_call(call_id, type: 'ended', call_id: call_id, reason: 'rejected')
    true
  end

  def terminate_call(call_id)
    signal_for_call(call_id, type: 'ended', call_id: call_id, reason: 'agent_hangup')
    true
  end

  # El negocio llama: sin permiso, como Meta, levanta NoCallPermission; si no, avisa a la página.
  def initiate_call(recipient, sdp_offer)
    wa_id = recipient.to_s.delete('+')
    raise Voice::CallErrors::NoCallPermission, 'Simulador: el cliente no ha dado permiso' unless permission_granted?(wa_id)

    call_id = "wacid.sim.#{SecureRandom.hex(8)}"
    remember_call(call_id, wa_id)
    push(wa_id, type: 'incoming', call_id: call_id, sdp: sdp_offer)
    { 'calls' => [{ 'id' => call_id }] }
  end

  def send_call_permission_request(recipient, body_text)
    wamid = "wamid.sim.#{SecureRandom.hex(8)}"
    push(recipient.to_s.delete('+'), type: 'permission_request', wamid: wamid, text: body_text)
    { 'messages' => [{ 'id' => wamid }] }
  end

  def update_calling_status(_status, icon: nil) # rubocop:disable Lint/UnusedMethodArgument
    true
  end

  def calling_settings
    { 'status' => 'ENABLED', 'simulator' => true }
  end

  # ── Lo que usa el controlador del simulador ──────────────────────────────────
  def remember_call(call_id, wa_id)
    ::Redis::Alfred.setex(format(CALLS_KEY, call_id: call_id), wa_id, TTL)
  end

  def grant_permission!(wa_id)
    ::Redis::Alfred.setex(permission_key(wa_id), '1', 7.days)
  end

  def permission_granted?(wa_id)
    ::Redis::Alfred.get(permission_key(wa_id)).present?
  end

  # Devuelve y vacía las señales pendientes de ese cliente.
  def take_signals(wa_id)
    key = signals_key(wa_id)
    raw = ::Redis::Alfred.get(key)
    ::Redis::Alfred.delete(key)
    raw.present? ? JSON.parse(raw) : []
  end

  # El mismo JSON que manda Meta (con metadata, para que el job encuentre la bandeja).
  def webhook(field, value)
    { object: 'whatsapp_business_account',
      entry: [{ id: whatsapp_channel.provider_config['business_account_id'],
                changes: [{ field: field, value: { messaging_product: 'whatsapp',
                                                   metadata: { display_phone_number: whatsapp_channel.phone_number.delete('+'),
                                                               phone_number_id: whatsapp_channel.provider_config['phone_number_id'] } }
                  .merge(value) }] }] }
  end

  private

  def signal_for_call(call_id, **signal)
    wa_id = ::Redis::Alfred.get(format(CALLS_KEY, call_id: call_id))
    push(wa_id, **signal) if wa_id.present?
  end

  def push(wa_id, **signal)
    key = signals_key(wa_id)
    raw = ::Redis::Alfred.get(key)
    lista = raw.present? ? JSON.parse(raw) : []
    ::Redis::Alfred.setex(key, (lista << signal.merge(at: Time.current.to_i)).to_json, TTL)
  end

  def signals_key(wa_id)
    format(SIGNALS_KEY, inbox_id: whatsapp_channel.inbox.id, wa_id: wa_id)
  end

  def permission_key(wa_id)
    format(PERMISSION_KEY, inbox_id: whatsapp_channel.inbox.id, wa_id: wa_id)
  end
end
