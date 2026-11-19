# frozen_string_literal: true

# «Atención a prospectos» › «Cómo platica»: lo que la empresa eligió en el asistente, en opciones (no
# en texto libre), convertido en reglas exactas para el agente. La primera de cada una es la
# recomendada (la que vale si no eligió nada).
#
#   doubts     answer   le contesta con lo que sabe y regresa a la pregunta pendiente
#              defer    no contesta dudas (no busca en ninguna fuente): un asesor se las resuelve
#   not_found  continue no tiene el dato: un asesor se lo confirma y sigue con sus preguntas
#              handoff  lo pasa a una persona
#   off_topic  redirect lo regresa con amabilidad a la plática
#              discard  lo descarta con amabilidad
#
# Siempre retoma la secuencia: Motor2::Skills::Qualify le recuerda en cada turno con qué pregunta
# termina su mensaje.
module Motor2::Functions::ProspectRules
  OPTIONS = { 'doubts' => %w[answer defer], 'not_found' => %w[continue handoff], 'off_topic' => %w[redirect discard] }.freeze

  RULES = {
    'doubts' => {
      'answer' => 'Si el cliente pregunta algo en vez de contestar, contéstale con lo que encuentres (buscar_en_fuentes) y, en ' \
                  'el mismo mensaje, regresa a la pregunta que quedó pendiente.',
      'defer' => 'NO contestas dudas ni das datos de la empresa (precios, horarios, características…): solo preguntas y ' \
                 'calificas. Si pregunta algo, dile con amabilidad que un asesor se lo resuelve en cuanto lo atienda y, en el ' \
                 'mismo mensaje, sigue con la pregunta pendiente. No inventes nada.'
    },
    'not_found' => {
      'continue' => 'Si buscas y no encuentras el dato, dile que no lo tienes a la mano y que un asesor se lo confirma, y sigue ' \
                    'con la pregunta pendiente. No lo pases a una persona solo por eso.',
      'handoff' => 'Si buscas y no encuentras el dato, pásalo a una persona (pasar_a_humano) con el motivo «no encontré: …».'
    },
    'off_topic' => {
      'redirect' => 'Si escribe algo que no tiene que ver con el negocio (EL NEGOCIO), no lo contestes: regrésalo con ' \
                    'amabilidad a la plática y sigue con la pregunta pendiente.',
      'discard' => 'Si escribe algo que no tiene que ver con el negocio (EL NEGOCIO), despídete con amabilidad y descártalo ' \
                   '(descartar) con el motivo.'
    }
  }.freeze

  module_function

  # La opción elegida (o la recomendada).
  def choice(answers, rule)
    answers.to_h[rule].presence_in(OPTIONS[rule]) || OPTIONS[rule].first
  end

  def choices(answers) = OPTIONS.keys.index_with { |rule| choice(answers, rule) }

  # Para guardar: solo valores conocidos.
  def sanitize(raw) = OPTIONS.to_h { |rule, values| [rule, raw[rule].to_s.presence_in(values) || values.first] }

  def block(answers)
    "CÓMO PLATICAS (lo eligió la empresa; manda sobre lo anterior):\n" \
      "#{choices(answers).map { |rule, value| "- #{RULES[rule][value]}" }.join("\n")}"
  end

  # Sin contestar dudas no hay búsqueda: el agente no tiene con qué buscar.
  def answers_doubts?(answers) = choice(answers, 'doubts') == 'answer'
end
