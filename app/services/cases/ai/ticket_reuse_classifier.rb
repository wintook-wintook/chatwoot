# frozen_string_literal: true

# ================================================================================
# @tickets_cases (@crear_ticket_multiple) — Clasificador de reuso de caso
# ================================================================================
# Servicio: Cases::Ai::TicketReuseClassifier
#
# Cuando el contacto YA tiene un caso activo y llega un mensaje nuevo, `@crear_ticket`
# normal siempre lo vincula ciegamente ("ya tienes un caso en curso"). Con
# `@crear_ticket_multiple` (docs/vault-tickets Pendiente.md, 2026-09-04) se clasifica
# primero qué es el mensaje respecto al caso activo:
#   - "same_case": agrega info / confirma / sigue el mismo hilo → se vincula, sin preguntar.
#   - "technical_question": pregunta de catálogo aislada, sin relación con el caso → se
#     resuelve por KBase, nunca se vincula.
#   - "new_request": describe un trabajo distinto → el cliente confirma antes de separar.
# Ante duda, siempre "same_case" — nunca se crea un caso nuevo sin confirmación explícita.
# ================================================================================

class Cases::Ai::TicketReuseClassifier < Cases::Ai::BaseService
  VALID_CLASSIFICATIONS = %w[same_case technical_question new_request].freeze

  def classify(conversation_text:, active_ticket_summary:)
    raw = chat(system: classify_system_prompt, user: classify_user_prompt(conversation_text, active_ticket_summary),
               json: true, max_tokens: 150)
    result = raw.is_a?(Hash) ? raw['classification'].to_s.strip : nil
    VALID_CLASSIFICATIONS.include?(result) ? result : 'same_case'
  rescue StandardError => e
    Rails.logger.warn "[TicketReuseClassifier] ⚠️ classify falló: #{e.message}"
    'same_case'
  end

  # true SOLO si el cliente confirma EXPLÍCITAMENTE que es un caso nuevo/aparte. Cualquier
  # respuesta ambigua, evasiva o que no conteste la pregunta → false (nunca se asume "sí").
  def confirm_new_request?(reply_text)
    raw = chat(system: confirm_system_prompt, user: reply_text.to_s, json: true, max_tokens: 50)
    raw.is_a?(Hash) && raw['is_new'] == true
  rescue StandardError => e
    Rails.logger.warn "[TicketReuseClassifier] ⚠️ confirm_new_request? falló: #{e.message}"
    false
  end

  private

  def classify_system_prompt
    <<~PROMPT.strip
      El cliente ya tiene un caso de soporte ABIERTO. Analiza su ÚLTIMO mensaje (con el resto
      de la conversación como contexto) y clasifícalo en EXACTAMENTE una categoría:

      - "same_case": el mensaje agrega información, confirma algo, o hace una pregunta de
        seguimiento sobre EL MISMO trabajo/caso ya abierto. Es la categoría por defecto —
        ante la duda, usá esta.
      - "technical_question": el mensaje es una pregunta técnica/de catálogo AISLADA (ej.
        "qué capacidad tiene tal unidad") que NO tiene relación directa con avanzar el caso
        abierto — el cliente solo quiere información, no está describiendo ni ampliando su
        solicitud.
      - "new_request": el mensaje describe un trabajo/servicio CLARAMENTE DISTINTO al que ya
        está abierto (otro origen/destino, otro tipo de servicio, otra fecha sin relación) —
        no una ampliación ni una corrección del caso actual, sino algo nuevo e independiente.

      Ante cualquier ambigüedad, preferí "same_case" — nunca clasifiques como "new_request"
      salvo que el mensaje deje claro que es un trabajo distinto.

      Responde EXCLUSIVAMENTE con JSON:
      { "classification": "same_case|technical_question|new_request" }
    PROMPT
  end

  def classify_user_prompt(conversation_text, active_ticket_summary)
    <<~PROMPT.strip
      CASO ACTIVO: #{active_ticket_summary.presence || '(sin resumen disponible)'}

      CONVERSACIÓN (el último mensaje es el que hay que clasificar):
      #{conversation_text}
    PROMPT
  end

  def confirm_system_prompt
    <<~PROMPT.strip
      Al cliente se le preguntó si lo que está pidiendo es un caso NUEVO y aparte, o parte de
      su caso ya abierto. Analiza su respuesta y responde EXCLUSIVAMENTE con JSON:
      { "is_new": true/false }
      true SOLO si confirma con claridad que es algo nuevo/aparte/distinto. false en cualquier
      otro caso (dice que es lo mismo, no contesta claro, cambia de tema, etc.) — ante la duda,
      false.
    PROMPT
  end
end
