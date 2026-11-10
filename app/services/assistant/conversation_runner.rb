# frozen_string_literal: true

# Asistente (Dali) — manda la respuesta confirmada por el canal de la conversación, a nombre
# del usuario (Messages::MessageBuilder, como al escribir en la pantalla). Se vuelve a revisar
# todo: permisos, la ventana de 24 h y la plantilla. Se incluye en Assistant::Executor.
module Assistant::ConversationRunner
  def run_reply(payload)
    raise Assistant::Executor::Refused, 'No tienes permiso para contestar conversaciones.' unless @grant.writable?(:conversations)

    conversation = @tools.find_conversation(payload['conversation_id'])
    params = reply_params(conversation, payload)
    Messages::MessageBuilder.new(@user, conversation, params.merge(private: false)).perform
    done("Respuesta enviada a #{conversation.contact&.name}", "#{base}/conversations/#{conversation.display_id}")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  private

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
