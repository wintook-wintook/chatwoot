# frozen_string_literal: true

# @waba_templates / coexistencia
# Refleja en Chatwoot los mensajes que un agente responde desde la WhatsApp Business App
# (móvil) cuando el número está en COEXISTENCIA. Meta los emite como `message_echoes`;
# aquí se convierten en mensajes SALIENTES de la conversación correcta.
#
# Reusa el pipeline de IncomingMessageBaseService (contacto/conversación/adjuntos) pero:
#   - resuelve el contacto por `to` (el CLIENTE), no por `contacts[]`;
#   - fuerza message_type :outgoing con sender nil (enviado desde el móvil, sin agente);
#   - deduplica por source_id (los mensajes que Chatwoot envió también regresan como echo);
#   - `edit`/`revoke` (editar/borrar en el móvil) modifican el mensaje original, no crean uno nuevo.
#
# ⚠️ Requiere suscribir el campo de coexistencia a mano en Meta App Dashboard → WhatsApp →
#    Configuration → Webhooks. El nombre/estructura exacta puede variar; aquí se detecta por
#    la presencia de `message_echoes` en el value del webhook.
class Whatsapp::EchoMessageService < Whatsapp::IncomingMessageBaseService
  # Ediciones y borrados hechos desde el móvil: no traen media; se aplican sobre el mensaje original.
  MOBILE_CHANGE_TYPES = %w[edit revoke].freeze

  def perform
    echoes = processed_params.try(:[], :message_echoes)
    return if echoes.blank?

    echo = echoes.first
    # Normaliza el echo a forma de "messages" para reusar los helpers de la base.
    @processed_params = processed_params.merge(messages: [echo])

    return apply_mobile_change(echo) if MOBILE_CHANGE_TYPES.include?(message_type)
    return if unprocessable_message_type?(message_type)
    return if find_message_by_source_id(echo[:id]) # dedup: Chatwoot ya lo envió

    set_message_type
    set_contact
    return unless @contact

    set_conversation
    create_messages
  end

  private

  # Mismo extractor que el servicio de entrada Cloud: el value del primer change.
  def processed_params
    @processed_params ||= params[:entry].try(:first).try(:[], 'changes').try(:first).try(:[], 'value')
  end

  def set_message_type
    @message_type = :outgoing
  end

  # El destinatario (cliente) define el contacto; el emisor es el negocio (móvil) → sin agente.
  def set_contact
    waid = @processed_params[:messages].first[:to]
    return if waid.blank?

    waid = brazil_phone_number?(waid) ? normalised_brazil_mobile_number(waid) : waid
    waid = processed_waid(waid)

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: waid,
      inbox: inbox,
      contact_attributes: { phone_number: "+#{waid}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
    @sender = nil
  end

  # Si el original no está en Chatwoot (enviado antes de conectar el canal) no hay nada que reflejar.
  def apply_mobile_change(echo)
    change = echo[echo[:type]] || {}
    return if change[:original_message_id].blank?

    original = inbox.messages.find_by(source_id: change[:original_message_id])
    return if original.blank?

    echo[:type] == 'revoke' ? revoke_message(original) : edit_message(original, change[:message] || {})
  end

  # Mismo formato que un borrado por estado `deleted` (ver IncomingMessageBaseService).
  def revoke_message(message)
    return if message.content_attributes['deleted']

    message.update!(content: "#{I18n.t('conversations.messages.deleted')}\n#{message.content}",
                    content_attributes: message.content_attributes.merge(deleted: true))
  end

  def edit_message(message, edited)
    new_content = message_content(edited) || edited.dig(edited[:type], :caption)
    return if new_content.blank? || new_content == message.content

    message.update!(content: new_content,
                    content_attributes: message.content_attributes.merge(is_edited: true, previous_content: message.content))
  end

  # Marca el mensaje como enviado desde el móvil (para distinguirlo en la UI/reportes).
  def create_message(message)
    super
    @message.content_attributes = (@message.content_attributes || {}).merge(external_created_via: 'whatsapp_mobile')
    @message
  end
end
