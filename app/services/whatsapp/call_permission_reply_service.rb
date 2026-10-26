# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — EL CLIENTE RESPONDIÓ «PERMITIR LLAMADAS»
# ================================================================================
# Llega como mensaje interactivo (type=call_permission_reply). Se reconoce la
# conversación por el wamid de la solicitud (context.id), no por «la más reciente»: un
# contacto puede tener varias abiertas. Si aceptó: actividad en la conversación y aviso
# en vivo a quien pidió el permiso y al asignado (voice_call.permission_granted).
# El permiso lo administra Meta (7 días, o permanente si el cliente lo eligió); aquí solo
# se avisa. Si lo rechazó no se hace nada.
# ================================================================================
class Whatsapp::CallPermissionReplyService
  pattr_initialize [:inbox!, :params!]

  def perform
    mensaje = params.dig(:entry, 0, :changes, 0, :value, :messages, 0) || {}
    respuesta = mensaje.dig(:interactive, :call_permission_reply) || {}
    return unless respuesta[:response] == 'accept'

    conversation = find_conversation(mensaje.dig(:context, :id))
    return unless conversation

    solicitante = conversation.additional_attributes.to_h[Whatsapp::CallPermissionRequestService::REQUESTER_KEY]
    clear_pending(conversation)
    activity!(conversation)
    Calls::Broadcaster.permission_granted(conversation, requester_id: solicitante,
                                                        contact_name: conversation.contact.name,
                                                        permanent: respuesta[:is_permanent] == true)
  end

  private

  def find_conversation(wamid)
    return if wamid.blank?

    inbox.conversations.where("additional_attributes ->> '#{Whatsapp::CallPermissionRequestService::MESSAGE_ID_KEY}' = ?", wamid).last
  end

  def clear_pending(conversation)
    conversation.update!(additional_attributes: conversation.additional_attributes.to_h
      .except(Whatsapp::CallPermissionRequestService::MESSAGE_ID_KEY))
  end

  def activity!(conversation)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
        content: I18n.t('conversations.activity.whatsapp_call.permission_granted', contact_name: conversation.contact.name) }
    )
  end
end
