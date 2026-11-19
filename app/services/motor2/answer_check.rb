# frozen_string_literal: true

# Motor 2.0 — ¿lo que dijo el cliente contesta la pregunta? Antes de guardar una respuesta de
# «Calificar» (Motor2::Skills::Qualify): el modelo del agente guardaba como respuesta lo que no lo
# es (una objeción, «sabe quién descubrió América», una duda sin «?»). Con reglas de palabras no se
# puede saber; esta revisión corta y aparte (AiModels::REVIEW, temperatura 0) sí.
#
#   Motor2::AnswerCheck.new(account).answers?(question: '¿Cuántos hijos tienes?', message: 'no me gusta el color')
#   → false
# Si OpenAI falla, se deja guardar (no se traba la plática).
class Motor2::AnswerCheck < Cases::Ai::BaseService
  SYSTEM = <<~TEXT
    Decides si el mensaje de un cliente CONTESTA una pregunta que le hizo un vendedor por chat.
    Contesta si da el dato que se pidió, aunque sea corto, informal, con errores de dedo o de pasada
    («para ir al trabajo» contesta «¿para qué lo quieres?»; «200 mil» contesta el presupuesto; «no tengo» o
    «todavía no sé» también contestan). NO contesta si pregunta otra cosa, pone un pretexto u objeción
    («no me gusta el color»), habla de otro tema, saluda o pide hablar con una persona.
    Responde solo JSON: {"contesta": true | false}
  TEXT

  def answers?(question:, message:)
    return true if question.blank? || message.blank?

    result = chat(system: SYSTEM, user: "PREGUNTA: #{question}\nMENSAJE DEL CLIENTE: #{message.to_s.first(500)}",
                  json: true, temperature: 0, max_tokens: 20)
    result.is_a?(Hash) && result.key?('contesta') ? result['contesta'] == true : true
  rescue StandardError => e
    Rails.logger.warn("[Motor2::AnswerCheck] #{e.class}: #{e.message}")
    true
  end

  TOPIC = <<~TEXT
    Decides si la pregunta de un cliente es sobre la EMPRESA o lo que vende (productos, precios, pagos,
    financiamiento, horarios, ubicación, envíos, garantías, cómo funciona…) o si es de OTRO tema (cultura
    general, chistes, personas que no tienen que ver, política…).
    Responde solo JSON: {"del_negocio": true | false}
  TEXT

  # ¿La pregunta es sobre la empresa o lo que vende? (para buscarla en sus fuentes). Si falla, sí.
  def about_business?(message:, business: nil)
    result = chat(system: TOPIC, user: "LA EMPRESA: #{business.presence || 'sin descripción'}\nPREGUNTA: #{message.to_s.first(500)}",
                  json: true, temperature: 0, max_tokens: 20)
    result.is_a?(Hash) && result.key?('del_negocio') ? result['del_negocio'] == true : true
  rescue StandardError => e
    Rails.logger.warn("[Motor2::AnswerCheck] #{e.class}: #{e.message}")
    true
  end

  private

  def model = AiModels::REVIEW
end
