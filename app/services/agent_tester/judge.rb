# frozen_string_literal: true

# Probador de agentes — ¿la respuesta cumple lo esperado? (para las corridas de lotes).
class AgentTester::Judge < Cases::Ai::BaseService
  SYSTEM = <<~TEXT
    Eres el juez de una prueba de un agente de chat. Te doy la plática, la última respuesta del agente y lo que se
    espera. Di si cumple lo esperado en lo esencial (no palabra por palabra).
    Si te doy "respuesta_mala_anterior", es la que el usuario marcó como mala y "esperado" es su comentario sobre
    ELLA (p. ej. «debería darlo en lista»): la prueba pasa si la respuesta nueva corrige eso que señaló y no repite
    el error; no exijas lo que la anterior ya hacía bien.
    Responde en JSON: {"ok": true|false, "reason": "una línea en español"}.
  TEXT

  # seen: lo que el agente tuvo a la vista (AgentTester::Seen). Un monto, porcentaje o código que
  # no esté ahí lo inventó: la prueba no pasa, diga lo que diga el modelo
  # (proyecto@predefinidas_que_contestan, KnowledgeBase::DataGuard).
  def call(turns:, reply:, expected:, bad_reply: nil, seen: nil)
    return { ok: false, reason: 'El agente no contestó nada.' } if reply.blank?

    inventados = seen.nil? ? [] : KnowledgeBase::DataGuard.invented(reply, seen)
    return { ok: false, reason: "Dio datos que no están en sus fuentes: #{inventados.join(', ')}.", invented: inventados } if inventados.any?
    return { ok: true, reason: 'Contestó (la prueba no dice qué se espera).' } if expected.blank?

    input = { platica: turns, respuesta: reply, esperado: expected }
    input[:respuesta_mala_anterior] = bad_reply if bad_reply.present?
    data = chat(system: SYSTEM, user: input.to_json, json: true, max_tokens: 200)
    data.is_a?(Hash) ? { ok: data['ok'] == true, reason: data['reason'].to_s.first(300) } : { ok: false, reason: 'No se pudo revisar.' }
  end

  private

  def model = AiModels::REVIEW
end
