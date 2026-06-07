# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3F — Seguimiento automático al cliente
# ================================================================================
# Servicio: Cases::Ai::FollowUp
#
# Redacta un mensaje de seguimiento para el cliente, adecuado al estado actual del
# ticket (esperando datos del cliente, validando solución, etc.). Devuelve el texto
# o nil ante fallo. NO envía nada: solo redacta el borrador (lo envía/copia el
# agente, o lo guarda el job para revisión).
# ================================================================================

class Cases::Ai::FollowUp < Cases::Ai::BaseService
  def draft(ticket)
    reply = chat(
      system: system_prompt,
      user:   user_prompt(ticket),
      temperature: 0.4,
      max_tokens: 400
    )
    reply.presence
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres un agente de soporte de Kontrolya. Redacta un mensaje BREVE y cordial de
      seguimiento al cliente en español, apropiado al estado actual del ticket:
        - en espera del cliente: recuérdale amablemente que esperas su información.
        - validando/resuelto: pídele que confirme si la solución funcionó.
        - en proceso: infórmale que seguimos trabajando en su caso.
      No incluyas asunto ni firma; solo el cuerpo del mensaje, listo para enviar.
    PROMPT
  end

  def user_prompt(ticket)
    <<~PROMPT.strip
      ESTADO ACTUAL: #{ticket.status}
      TÍTULO DEL TICKET: #{ticket.title}
      DESCRIPCIÓN: #{ticket.description.presence || '(sin descripción)'}
      FOLIO: #{ticket.folio}
    PROMPT
  end
end
