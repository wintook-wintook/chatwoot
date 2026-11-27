# frozen_string_literal: true

# Motor 2.0 — llena las variables de una plantilla de WhatsApp ({{1}}, {{nombre}}…) con datos reales (para
# escribir pasadas las 24 h: el recordatorio de la cita). Revisión corta (AiModels::REVIEW, temperatura 0).
#
#   Motor2::TemplateFiller.new(account: a).call(body: 'Hola {{1}}, tu cita es el {{2}}', variables: %w[1 2], facts: { … })
#   → { '1' => 'Mario', '2' => 'viernes 21 de noviembre, 10:00' }  ({} si no se pudo)
class Motor2::TemplateFiller < Cases::Ai::BaseService
  SYSTEM = <<~TEXT
    Llenas las variables de una plantilla de WhatsApp con los DATOS que te doy. Cada variable con el dato que le
    corresponde por el texto de la plantilla; nunca inventes. Responde solo JSON: {"valores": {"1": "..."}}
  TEXT

  def call(body:, variables:, facts:)
    return {} if variables.empty?

    user = "PLANTILLA: #{body}\nVARIABLES: #{variables.join(', ')}\nDATOS:\n#{facts.map { |k, v| "- #{k}: #{v}" }.join("\n")}"
    result = chat(system: SYSTEM, user: user, json: true, temperature: 0, max_tokens: 200)
    result.to_h['valores'].to_h.slice(*variables).transform_values(&:to_s).compact_blank
  rescue StandardError => e
    Rails.logger.warn("[Motor2::TemplateFiller] #{e.class}: #{e.message}")
    {}
  end

  private

  def model = AiModels::REVIEW
end
