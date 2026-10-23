# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F2) — WEBHOOKS DE LLAMADAS DE WHATSAPP
# ================================================================================
# El controlador manda aquí lo que es de llamadas; lo demás sigue en WhatsappEventsJob.
#
# En cola `critical` y no en `low`: el cliente oye timbrar ~60 s, y con prioridad estricta
# una campaña masiva en Sidekiq dejaría la llamada sin sonar.
#
# Meta manda dos formas bajo field=calls:
#   value.calls[]    eventos: connect (con el SDP) y terminate
#   value.statuses[] estados (type=call): RINGING, ACCEPTED (la contestó de verdad)
# Cada llamada se procesa con su propio candado (Redis) para que connect/estado/terminate
# no se crucen; si el candado está ocupado, el job se reintenta.
# Y la respuesta del cliente al «Permitir llamadas» llega como un mensaje interactivo.
#
# Sin la bandera de la cuenta o con las llamadas apagadas en la bandeja no se hace nada.
# Los servicios (Whatsapp::IncomingCallService, Whatsapp::CallPermissionReplyService)
# llegan en F3. Plan: docs/llamadas_whatsapp_plan.md
# ================================================================================
class Webhooks::WhatsappCallEventsJob < MutexApplicationJob
  include WhatsappChannelLookup

  queue_as :critical
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  CALL_LOCK_TIMEOUT = 30 # segundos

  def self.call_event?(params)
    params.dig(:entry, 0, :changes, 0, :field) == 'calls'
  end

  def self.permission_reply?(params)
    params.dig(:entry, 0, :changes, 0, :value, :messages, 0, :interactive, :type) == 'call_permission_reply'
  end

  def self.handles?(params)
    call_event?(params) || permission_reply?(params)
  end

  def perform(params = {})
    params = params.with_indifferent_access
    channel = find_channel_from_whatsapp_business_payload(params)
    return if channel_is_inactive?(channel) || !channel.voice_enabled?
    # feat/licencias (F3): en una cuenta suspendida nadie puede entrar a contestar.
    return if Licenses::Silence.silenced?(channel.account)

    return permission_reply(channel, params) if self.class.permission_reply?(params)

    call_events(channel, params)
  end

  private

  def call_events(channel, params)
    value = params.dig(:entry, 0, :changes, 0, :value) || {}

    Array(value[:calls]).each do |evento|
      with_call_lock(channel, evento[:id]) do
        Whatsapp::IncomingCallService.new(inbox: channel.inbox, params: { calls: [evento], contacts: value[:contacts] }).perform
      end
    end

    Array(value[:statuses]).each do |estado|
      next unless estado[:type] == 'call'

      with_call_lock(channel, estado[:id]) do
        Whatsapp::IncomingCallService.new(inbox: channel.inbox, params: { statuses: [estado] }).perform
      end
    end
  end

  def permission_reply(channel, params)
    Whatsapp::CallPermissionReplyService.new(inbox: channel.inbox, params: params).perform
  end

  def with_call_lock(channel, call_id, &)
    with_lock(format(::Redis::Alfred::WHATSAPP_CALL_MUTEX, inbox_id: channel.inbox.id, call_id: call_id), CALL_LOCK_TIMEOUT, &)
  end
end
