# frozen_string_literal: true

# Motor 2.0 — corre una prueba guardada: la plática hasta el último mensaje del cliente, la
# respuesta del agente (con la ficha guardada o con un cambio todavía sin aplicar) y un juez que
# dice si cumple lo esperado. Es lo que corre el entrenador antes de corregir y «Correr todas».
#
#   Motor2::TestRunner.new(template).run(test)                 → { ok:, reply:, reason: }
#   Motor2::TestRunner.new(template).run(test, draft: otro)    → igual, sin guardar nada
class Motor2::TestRunner < Cases::Ai::BaseService
  JUDGE = <<~TEXT
    Eres el juez de una prueba de un agente de chat. Te doy la plática, la respuesta del agente
    al último mensaje y lo que se espera. Di si la respuesta cumple lo esperado (en lo esencial,
    no palabra por palabra). Responde JSON: {"ok": true|false, "reason": "una línea en español"}.
  TEXT

  def initialize(template)
    super(account: template.account)
    @template = template
  end

  def run(test, draft: nil, save: true)
    result = Motor2::Probe.new(draft || @template, messages: history(test)).call
    verdict = result[:error] ? { ok: false, reason: result[:error] } : judge(test, result[:reply].to_s)
    verdict = verdict.merge(reply: result[:reply].to_s, at: Time.current.iso8601)
    test.update!(last_run: verdict) if save
    verdict
  end

  # Las que pasaban: si un cambio rompe alguna, el entrenador no lo aplica.
  def broken_by(draft, limit: 8)
    tests = Motor2Test.where(tracking_template_id: @template.id).order(updated_at: :desc).limit(limit)
    tests.select { |t| t.last_run['ok'] }.reject { |t| run(t, draft: draft, save: false)[:ok] }
  end

  private

  # Hasta el último mensaje del cliente (lo que sigue es lo que debe contestar).
  def history(test)
    turns = Array(test.turns).map { |t| t.to_h.symbolize_keys.slice(:role, :content) }
    last_user = turns.rindex { |t| t[:role].to_s == 'user' }
    last_user ? turns.first(last_user + 1) : turns
  end

  def judge(test, reply)
    return { ok: false, reason: 'El agente no contestó nada.' } if reply.blank?

    data = chat(system: JUDGE, user: { platica: history(test), respuesta: reply, esperado: test.expected }.to_json,
                json: true, max_tokens: 200)
    data.is_a?(Hash) ? { ok: data['ok'] == true, reason: data['reason'].to_s.first(300) } : { ok: false, reason: 'No se pudo revisar.' }
  end

  def model = AiModels::REVIEW
end
