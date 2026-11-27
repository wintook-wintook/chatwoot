# frozen_string_literal: true

# Asistente (Dali) — manda la respuesta confirmada por el canal de la conversación, a nombre
# del usuario (Messages::MessageBuilder, como al escribir en la pantalla). Se vuelve a revisar
# todo: permisos, la ventana de 24 h y la plantilla. Se incluye en Assistant::Executor.
module Assistant::ConversationRunner
  def run_reply(payload)
    conversation = @tools.find_conversation(payload['conversation_id'])
    raise Assistant::Executor::Refused, 'No tienes permiso para contestar conversaciones.' unless may_reply?(conversation)

    params = reply_params(conversation, payload)
    Messages::MessageBuilder.new(@user, conversation, params.merge(private: false)).perform
    to = conversation.internal? ? @tools.room_name(conversation) : conversation.contact&.name
    done("Mensaje enviado a #{to}", "#{base}/conversations/#{conversation.display_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  # Nota interna en la conversación: para el equipo (a quien lo mencionó), el cliente no la ve.
  def run_internal_note(payload)
    conversation = @tools.find_conversation(payload['conversation_id'])
    content = payload['content'].to_s.strip
    raise Assistant::Executor::Refused, 'Falta el texto de la nota.' if content.blank?
    raise Assistant::Executor::Refused, 'En el chat interno se contesta con un mensaje.' if conversation.internal?

    Messages::MessageBuilder.new(@user, conversation, { content: content, private: true }).perform
    done("Nota interna en la conversación ##{conversation.display_id}", "#{base}/conversations/#{conversation.display_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  # En el chat interno escribe cualquiera de la sala; a un cliente, con permiso de Conversaciones.
  def may_reply?(conversation)
    conversation.internal? || @grant.writable?(:conversations)
  end

  def reply_params(conversation, payload)
    if payload['template_name'].present?
      filled = @tools.fill_reply_template(conversation, payload)
      return { content: filled[:content], template_params: filled[:template_params] }
    end
    raise Assistant::Executor::Refused, 'Pasaron más de 24 h desde su último mensaje: usa una plantilla.' unless conversation.can_reply?

    content = payload['content'].to_s.strip
    raise Assistant::Executor::Refused, 'Falta el texto de la respuesta.' if content.blank?

    { content: content }
  end
end
