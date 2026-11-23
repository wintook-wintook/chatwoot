# frozen_string_literal: true

# Va como `prepend` en ContactTrackingJob (config/initializers/motor2.rb), sin editar el job del 1.0: después de mandar
# un toque, la conversación de un contacto de lista fría en cuarentena vuelve a quedar pospuesta y sin asignar
# (Motor2::ListConversation) y no se reabre antes del siguiente. Para todo lo demás no cambia nada.
module Motor2::ListConversationHook
  private

  def deliver(tracking)
    result = super
    Motor2::ListConversation.quiet!(tracking) if result == true
    result
  end

  # El 1.0 reabre la conversación antes de cada toque (y eso dispara la asignación automática de la bandeja): la de
  # un contacto en cuarentena se usa pospuesta, tal cual.
  def find_or_create_conversation(tracking)
    conversation = Conversation.find_by(id: tracking.conversation_id) if Motor2::ListConversation.quiet?(tracking)
    conversation&.snoozed? ? conversation : super
  end
end
