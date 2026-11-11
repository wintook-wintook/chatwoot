# frozen_string_literal: true

# Asistente (Dali) — funciones de conversaciones con clientes (formato de OpenAI). Lo que hacen
# vive en Assistant::ConversationTools.
module Assistant::ConversationToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('my_conversations', 'Lo que espera al usuario. conversations: sus conversaciones abiertas con clientes; por omisión ' \
                             'solo las que esperan respuesta (la que más lleva esperando primero). Por omisión también: ' \
                             'mentions (lo mencionaron en una nota interna y no ha escrito desde entonces), internal_chat ' \
                             '(salas del chat interno sin leer) y, si reparte, unassigned (sin asignar esperando).',
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
         %w[conversation_id]),
    D.fn('propose_internal_note', 'Propone una nota interna en una conversación con cliente (el cliente no la ve): para ' \
                                  'contestarle al equipo, p. ej. a quien mencionó al usuario. Requiere confirmación.',
         { conversation_id: D.int('Número de la conversación'), content: D.str('El texto de la nota') },
         %w[conversation_id content])
  ].freeze
end
