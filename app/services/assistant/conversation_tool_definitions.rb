# frozen_string_literal: true

# Asistente (Dali) — funciones de conversaciones con clientes (formato de OpenAI). Lo que hacen
# vive en Assistant::ConversationTools.
module Assistant::ConversationToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('my_conversations', 'Las conversaciones abiertas asignadas al usuario. Por omisión solo las que esperan respuesta ' \
                             '(la que más lleva esperando primero), con su último mensaje.',
         { filter: { type: 'string', enum: %w[unanswered open], description: 'unanswered (por omisión) u open = todas las abiertas' } }),
    D.fn('read_conversation', 'Lee los últimos mensajes de una conversación, si se le puede escribir libre (can_reply) y, ' \
                              'si no, las plantillas aprobadas con sus variables.',
         { conversation_id: D.int('Número de la conversación (id de my_conversations)') }, %w[conversation_id]),
    D.fn('propose_reply', 'Propone la respuesta al cliente en una tarjeta; al confirmar sale por su canal a nombre del usuario. ' \
                          'Con can_reply manda content; si no, solo una plantilla (template_name y sus variables).',
         { conversation_id: D.int('Número de la conversación'),
           content: D.str('El mensaje para el cliente, en el tono del usuario'),
           template_name: D.str('Plantilla aprobada (solo con la ventana de 24 h cerrada)'),
           template_language: D.str('Idioma de la plantilla'),
           template_values: { type: 'object', description: 'Variables de la plantilla: { "1": "Mario", … } con datos reales' } },
         %w[conversation_id])
  ].freeze
end
