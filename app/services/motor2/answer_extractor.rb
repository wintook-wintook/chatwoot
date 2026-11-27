# frozen_string_literal: true

# Motor 2.0 — «Atención a prospectos»: qué preguntas para calificarlo YA contestó el prospecto en la plática
# (aunque sea de pasada, fuera de orden o en el mismo mensaje en que pregunta otra cosa: «busco una
# camioneta para la familia, ¿qué precio tienen?» contesta «¿Qué necesitas?»). Lo decide el código en
# cada mensaje (antes dependía de que el modelo llamara guardar_respuesta, y a veces no lo hacía y
# repetía la pregunta). Revisión corta y aparte (AiModels::REVIEW, temperatura 0).
#
# Preguntas condicionales: «¿Cuántos empleados tienen? [solo si es empresa]» → si por la plática no
# aplica (es para él), queda «no aplica» y no se hace.
#
#   Motor2::AnswerExtractor.new(account: a).call(questions: [{ number:, ask:, condition: }], history:)
#   → { 3 => '250 mil', 5 => 'no aplica' }
# Si OpenAI falla: {} (sigue como antes: el modelo guarda con guardar_respuesta).
class Motor2::AnswerExtractor < Cases::Ai::BaseService
  NOT_APPLICABLE = 'no aplica'
  HISTORY = 12

  SYSTEM = <<~TEXT
    Lees una plática entre un AGENTE de ventas y un CLIENTE. Para cada PREGUNTA PENDIENTE, di si el CLIENTE ya la
    contestó en cualquier mensaje (aunque no se la hayan preguntado, de pasada, o junto con otra pregunta suya).
    - Solo cuenta lo que dijo el CLIENTE, con sus palabras resumidas («una camioneta para la familia», «250 mil»).
    - Si lo que dijo no contesta exactamente esa pregunta, no la pongas (para «¿Para cuándo?», «para viajar» no
      contesta). Una pregunta del cliente o una objeción no es respuesta.
    - No deduzcas: si tendrías que suponerlo («busco algo para la familia» NO dice para quién es exactamente), no
      la pongas; mejor que se la pregunten.
    - Si la pregunta trae una condición («solo si es empresa») y por la plática es claro que NO aplica, pon
      "no aplica".
    Responde solo JSON con las que sí contestó: {"respuestas": [{"numero": 1, "respuesta": "..."}]}
  TEXT

  def call(questions:, history:)
    return {} if questions.empty?

    result = chat(system: SYSTEM, user: context(questions, history), json: true, temperature: 0, max_tokens: 300)
    clean(result, questions)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::AnswerExtractor] #{e.class}: #{e.message}")
    {}
  end

  private

  def model = AiModels::REVIEW

  def context(questions, history)
    lines = ['PREGUNTAS PENDIENTES:']
    questions.each { |q| lines << "#{q[:number]}. #{q[:ask]}#{" (solo si #{q[:condition]})" if q[:condition].present?}" }
    lines << 'PLÁTICA:'
    Array(history).last(HISTORY).each { |m| lines << "#{m[:role].to_s == 'user' ? 'CLIENTE' : 'AGENTE'}: #{m[:content].to_s.first(500)}" }
    lines.join("\n")
  end

  def clean(result, questions)
    numbers = questions.pluck(:number)
    Array(result.to_h['respuestas']).each_with_object({}) do |row, out|
      number = row.to_h['numero'].to_i
      text = row.to_h['respuesta'].to_s.squish.first(300)
      out[number] = text if numbers.include?(number) && text.present?
    end
  end
end
