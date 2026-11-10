# frozen_string_literal: true

# Asistente (Dali) — Seguimiento IA y plantillas de seguimiento (formato de OpenAI). Lo que
# hacen vive en Assistant::FollowUpTools y Assistant::FollowUpPresetTools.
module Assistant::FollowUpToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    # Seguimiento IA — el agente nuevo con herramientas (por omisión al «dale seguimiento»)
    D.fn('propose_follow_up', "Propone delegar el seguimiento del cliente al #{AiFollowUp::DISPLAY_NAME} (el agente nuevo, sin " \
                              'elegir agente). Si ya corre uno en esa conversación, la tarjeta lo reemplaza. Requiere confirmación.',
         { case_id: D.int('Id del caso'), contact_id: D.int('Id del contacto'),
           conversation_id: D.int('Número de la conversación (omitir = la del caso o la más reciente)'),
           objective: D.str('Qué debe lograr, concreto: «que confirme la cotización 1520 o saber por qué no»'),
           instruction: D.str('Indicaciones para este cliente (tono, qué ofrecer, qué no decir)'),
           starts_at: D.str('Primer mensaje, hora local YYYY-MM-DDTHH:MM (omitir = ahora, o el siguiente intento del que corre)'),
           max_attempts: D.int('Cuántas veces insistir sin respuesta (1 a 10, default 3)'),
           interval_value: D.int('Cada cuánto (número)'), interval_unit: { type: 'string', enum: %w[minutes hours days] },
           template_name: D.str('Solo si el usuario nombra una plantilla de WhatsApp para reabrir la ventana de 24 h ' \
                                '(omitir = el agente elige la más conveniente)'),
           preset: D.str('Nombre exacto de la plantilla de seguimiento a usar (de la lista del prompt); lo demás la ajusta'),
           on_finish: { type: 'string', enum: %w[notify assign] } }, []),
    D.fn('follow_up_presets', 'Lista las plantillas de seguimiento de la cuenta (nombre y de qué se trata). Úsala si la lista ' \
                              'del prompt dice que hay más.', { query: D.str('Palabras para filtrar (opcional)') }),
    D.fn('propose_save_follow_up_preset', 'Propone guardar un seguimiento como plantilla de seguimiento para volver a usarla. ' \
                                          'Requiere confirmación.',
         { name: D.str('Nombre corto y claro, p. ej. «Cobranza amable 3 intentos»'), objective: D.str('Qué debe lograr'),
           instruction: D.str('Indicaciones'), max_attempts: D.int('Intentos (1 a 10)'), interval_value: D.int('Cada cuánto'),
           interval_unit: { type: 'string', enum: %w[minutes hours days] }, template_name: D.str('Plantilla de WhatsApp preferida') },
         %w[name objective])
  ].freeze
end
