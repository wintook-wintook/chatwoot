# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — PEDIRLE AL CLIENTE PERMISO PARA LLAMARLE
# ================================================================================
# Cuando Meta rechaza una saliente con 138006 se manda el mensaje interactivo
# «Permitir llamadas». Reglas de Meta (confirmadas 22/10/2026):
#   máx. 1 solicitud cada 24 h y 2 cada 7 días, por cliente y número de negocio.
# Por eso el historial vive en el CONTACTO, por bandeja, y no en la conversación: el
# límite vale aunque el cliente tenga varias conversaciones.
#   contact.additional_attributes['whatsapp_call_permission'][inbox_id] = { 'requested_at' => [iso…] }
# En la conversación queda el wamid de la solicitud (la respuesta del cliente lo trae en
# context.id) y quién la pidió (a quien se avisa cuando acepta).
#
# Devuelve un hash: { status: 'permission_requested' } · { status: 'permission_limit',
# next_allowed_at: … } · { status: 'failed' }.
# ================================================================================
class Whatsapp::CallPermissionRequestService
  DAILY_LIMIT = 1
  WEEKLY_LIMIT = 2
  CONTACT_KEY = 'whatsapp_call_permission'
  MESSAGE_ID_KEY = 'call_permission_request_message_id'
  REQUESTER_KEY = 'call_permission_requested_by'

  pattr_initialize [:conversation!, :recipient!, :requester!]

  def perform
    conversation.contact.with_lock do
      siguiente = next_allowed_at
      next { status: 'permission_limit', next_allowed_at: siguiente.iso8601 } if siguiente

      enviado = send_request
      next { status: 'failed' } if enviado.blank?

      record!(enviado.dig('messages', 0, 'id'))
      activity!
      { status: 'permission_requested' }
    end
  end

  private

  def inbox
    conversation.inbox
  end

  def history
    Array(conversation.contact.additional_attributes.to_h.dig(CONTACT_KEY, inbox.id.to_s, 'requested_at'))
      .filter_map { |fecha| Time.zone.parse(fecha) rescue nil } # rubocop:disable Style/RescueModifier
      .select { |fecha| fecha > 7.days.ago }
  end

  # nil = se puede pedir ahora; si no, cuándo se podrá.
  def next_allowed_at
    semana = history.sort
    ultimo_dia = semana.select { |fecha| fecha > 24.hours.ago }
    return ultimo_dia.min + 24.hours if ultimo_dia.size >= DAILY_LIMIT
    return semana.first(semana.size - WEEKLY_LIMIT + 1).max + 7.days if semana.size >= WEEKLY_LIMIT

    nil
  end

  def send_request
    texto = inbox.channel.provider_config['call_permission_request_body'].presence ||
            I18n.t('conversations.messages.whatsapp.call_permission_request_body')
    inbox.channel.calls_provider.send_call_permission_request(recipient, texto)
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] no se pudo pedir permiso: #{e.class} #{e.message}"
    nil
  end

  def record!(wamid)
    record_on_contact!
    conversation.update!(additional_attributes: (conversation.additional_attributes || {})
      .merge(MESSAGE_ID_KEY => wamid, REQUESTER_KEY => requester.id))
  end

  # El historial va en el contacto, por bandeja (el límite de Meta es por cliente y número).
  def record_on_contact!
    contacto = conversation.contact
    atributos = contacto.additional_attributes.to_h
    permisos = atributos[CONTACT_KEY].to_h
    fechas = (history.map(&:iso8601) + [Time.current.iso8601]).last(WEEKLY_LIMIT + 1)
    permisos[inbox.id.to_s] = permisos[inbox.id.to_s].to_h.merge('requested_at' => fechas)
    contacto.update!(additional_attributes: atributos.merge(CONTACT_KEY => permisos))
  end

  def activity!
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
        content: I18n.t('conversations.activity.whatsapp_call.permission_requested', contact_name: conversation.contact.name) }
    )
  end
end
