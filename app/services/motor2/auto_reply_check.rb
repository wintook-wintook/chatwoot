# frozen_string_literal: true

# Motor 2.0 — ¿este mensaje lo escribió una persona o es la respuesta automática de su WhatsApp Business? Solo se
# pregunta cuando llegó a los pocos segundos y no trae una frase típica (Motor2::AutoReply). Revisión corta
# (AiModels::REVIEW, temperatura 0); si falla, se toma como de una persona (no se pierde una respuesta real).
class Motor2::AutoReplyCheck < Cases::Ai::BaseService
  SYSTEM = <<~TEXT
    Decides si un mensaje de WhatsApp que llegó segundos después de que una empresa le escribió a alguien es una
    RESPUESTA AUTOMÁTICA de su WhatsApp Business (saludo de bienvenida, horario, «en breve te atendemos», menú de
    opciones, catálogo, mensaje de ausencia) o lo escribió una PERSONA contestando («sí», «¿cuánto cuesta?», «no me
    interesa», «quién eres»). Si tienes duda, es de una persona.
    Responde solo JSON: {"automatica": true | false}
  TEXT

  def auto?(text)
    return false if text.blank?

    result = chat(system: SYSTEM, user: "MENSAJE: #{text.to_s.first(600)}", json: true, temperature: 0, max_tokens: 20)
    result.is_a?(Hash) && result['automatica'] == true
  rescue StandardError => e
    Rails.logger.warn("[Motor2::AutoReplyCheck] #{e.class}: #{e.message}")
    false
  end

  private

  def model = AiModels::REVIEW
end
