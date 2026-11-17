# frozen_string_literal: true

# Probador de agentes — ¿la respuesta cumple lo esperado? (para las corridas de lotes).
class AgentTester::Judge < Cases::Ai::BaseService
  SYSTEM = <<~TEXT
    Eres el juez de una prueba de un agente de chat. Te doy la plática, la última respuesta del agente y lo que se
    espera. Di si cumple lo esperado en lo esencial (no palabra por palabra). Responde en JSON:
    {"ok": true|false, "reason": "una línea en español"}.
  TEXT

  def call(turns:, reply:, expected:)
    return { ok: false, reason: 'El agente no contestó nada.' } if reply.blank?
    return { ok: true, reason: 'Contestó (la prueba no dice qué se espera).' } if expected.blank?

    data = chat(system: SYSTEM, user: { platica: turns, respuesta: reply, esperado: expected }.to_json, json: true, max_tokens: 200)
    data.is_a?(Hash) ? { ok: data['ok'] == true, reason: data['reason'].to_s.first(300) } : { ok: false, reason: 'No se pudo revisar.' }
  end

  private

  def model = Assistant::Settings.model_for(@account)
end
