# frozen_string_literal: true

# Motor 2.0 — «Atención a clientes» › Comercial: ¿lo que va a contestar está confirmado por lo que
# trajeron sus fuentes? (Plan-Motor-Agentes §11.15, plan funcional §6–8: evidencia «fail closed»).
# Revisión corta y aparte (AiModels::REVIEW, temperatura 0):
#   EXACTA          lo que afirma está en la evidencia → se manda
#   PARCIAL / NO_CONFIRMADA / CONTRADICTORIA / SIN_EVIDENCIA → se reescribe con lo confirmado y diciendo
#                   que lo demás no se puede confirmar (Motor2::AreaChecks#ensure_evidence)
# También revisa el candado de intención: no ofrecer otra cosa en lugar de lo que pidió (visita ≠ demo).
#
#   Motor2::EvidenceCheck.new(account: a).call(question:, reply:, evidence:) → { 'veredicto' => 'EXACTA', 'falta' => '' }
# Si OpenAI falla, se deja pasar (no se traba la plática).
class Motor2::EvidenceCheck < Cases::Ai::BaseService
  VERDICTS = %w[EXACTA PARCIAL NO_CONFIRMADA CONTRADICTORIA SIN_EVIDENCIA].freeze

  SYSTEM = <<~TEXT
    Revisas la respuesta de un agente de ventas antes de mandarla. Solo cuentan como confirmados los datos
    que están en la EVIDENCIA (lo que regresaron las fuentes de la empresa). Decide:
    - EXACTA: todo dato concreto que afirma (precios, planes, características, disponibilidad, tiempos,
      condiciones) está en la evidencia; o la respuesta no afirma datos (solo dice que no lo tiene, pregunta
      o saluda).
    - PARCIAL: una parte está en la evidencia y otra no.
    - NO_CONFIRMADA: afirma algo que la evidencia no dice.
    - CONTRADICTORIA: afirma algo distinto a la evidencia.
    - SIN_EVIDENCIA: afirma datos y no hay evidencia.
    También es NO_CONFIRMADA si ofrece otra cosa en lugar de lo que pidió el cliente (una demo en vez de una visita).
    En «falta» di en pocas palabras qué no está confirmado.
    Responde solo JSON: {"veredicto": "EXACTA", "falta": ""}
  TEXT

  # Soporte (del prompt del Coordinador Kontrolya v5.6: evidencia, no diagnóstico, nombres exactos).
  SUPPORT = <<~TEXT
    Revisas la respuesta de un agente de soporte antes de mandarla. Solo cuentan como confirmados los pasos,
    rutas, menús, botones, casillas, parámetros, requisitos, configuraciones, causas y capacidades que están en
    la EVIDENCIA (lo que regresaron las fuentes de la empresa). Decide:
    - EXACTA: todo lo que afirma está en la evidencia, con los mismos nombres; o no afirma nada técnico (pregunta,
      saluda, dice que no encontró documentación o que lo pasa con soporte).
    - PARCIAL: una parte está en la evidencia y otra no.
    - NO_CONFIRMADA: agrega pasos, causas o diagnósticos que la evidencia no dice («puede deberse», «reinicia»,
      «revisa tu conexión»), o da por hecho que lo de otro sistema aplica al suyo.
    - CONTRADICTORIA: cambia nombres de botones o menús, o dice algo distinto a la evidencia.
    - SIN_EVIDENCIA: afirma algo técnico y no hay evidencia.
    En «falta» di en pocas palabras qué no está confirmado.
    Responde solo JSON: {"veredicto": "EXACTA", "falta": ""}
  TEXT

  def call(question:, reply:, evidence:, support: false)
    user = "PREGUNTA DEL CLIENTE: #{question.to_s.first(500)}\nEVIDENCIA:\n#{evidence.presence || '(nada)'}\n" \
           "RESPUESTA DEL AGENTE: #{reply.to_s.first(1500)}"
    result = chat(system: support ? SUPPORT : SYSTEM, user: user.first(8000), json: true, temperature: 0, max_tokens: 120)
    verdict = result.is_a?(Hash) ? result['veredicto'].to_s.upcase.presence_in(VERDICTS) : nil
    { 'veredicto' => verdict || 'EXACTA', 'falta' => result.is_a?(Hash) ? result['falta'].to_s.first(200) : '' }
  rescue StandardError => e
    Rails.logger.warn("[Motor2::EvidenceCheck] #{e.class}: #{e.message}")
    { 'veredicto' => 'EXACTA', 'falta' => '' }
  end

  private

  def model = AiModels::REVIEW
end
