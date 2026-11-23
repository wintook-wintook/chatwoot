# frozen_string_literal: true

# Campaña con Vendedor IA por correo con lista fría: las conversaciones de los contactos en cuarentena no llenan la
# bandeja. Se abren sin asignar (TrackingCampaigns::TrackingBuilder) y, después de cada toque, quedan pospuestas
# (snoozed) sin asignar: no salen en «Abiertas» ni le llegan a nadie. Cuando el contacto contesta, Chatwoot reabre la
# conversación sola (Message#reopen_conversation) y el contacto deja la cuarentena (ProspectLists.promote!).
module Motor2::ListConversation
  module_function

  def quiet?(tracking)
    tracking.tracking_campaign&.motor2? && tracking.contact&.list_quarantine?
  end

  # Después de mandar un toque (Motor2::ListConversationHook).
  def quiet!(tracking)
    return unless quiet?(tracking)

    conversation = Conversation.find_by(id: tracking.reload.conversation_id)
    return unless conversation && !conversation.resolved?

    conversation.update_columns(status: Conversation.statuses[:snoozed], assignee_id: nil, snoozed_until: nil, # rubocop:disable Rails/SkipsModelValidations
                                updated_at: Time.current)
  end
end
