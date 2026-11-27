# frozen_string_literal: true

# «Atención a prospectos» › «Cómo platica»: lo que la empresa eligió en el asistente, en opciones (no
# en texto libre), convertido en reglas exactas para el agente. La primera de cada una es la
# recomendada (la que vale si no eligió nada).
#
#   doubts     answer   le contesta con lo que sabe y regresa a la pregunta pendiente
#              defer    no contesta dudas (no busca en ninguna fuente): un asesor se las resuelve
#   not_found  advisor  (solo si contesta dudas) no tiene el dato: un asesor se lo confirma y sigue
#              silent   no tiene el dato y sigue con sus preguntas (sin prometer asesor)
#   off_topic  redirect (solo si contesta dudas) lo regresa con amabilidad a la plática
#              answer   le contesta en 1 o 2 líneas (sin buscar) y sigue
#   human      finish_first  pide terminar las que faltan (máx. 2) y lo pasa; si insiste o se molesta, ya
#              now           lo pasa de inmediato
#
# Siempre retoma la secuencia: Motor2::Skills::Qualify le recuerda en cada turno con qué pregunta
# termina su mensaje, conectando («Si te parece, seguimos: solo me faltan 2 preguntas…») cuando se
# desvió. Quien pide una persona lo lleva la cuenta el código (Qualify: human_asked / human_pending).
module Motor2::Functions::ProspectRules
  OPTIONS = { 'doubts' => %w[answer defer], 'not_found' => %w[advisor silent], 'off_topic' => %w[redirect answer],
              'human' => %w[finish_first now] }.freeze
  # Solo aplican si contesta dudas.
  NEEDS_DOUBTS = %w[not_found off_topic].freeze
  # Valores de antes (19/11): «lo pasa a una persona» y «lo descarta» se quitaron.
  LEGACY = { 'not_found' => { 'continue' => 'advisor', 'handoff' => 'advisor' },
             'off_topic' => { 'discard' => 'redirect' } }.freeze
  MAX_BEFORE_HUMAN = 2

  RULES = {
    'doubts' => {
      'answer' => 'Si el cliente pregunta algo en vez de contestar, contéstale con lo que encuentres (buscar_en_fuentes) y, en ' \
                  'el mismo mensaje, regresa a la pregunta que quedó pendiente.',
      'defer' => 'NO contestas dudas ni das datos de la empresa (precios, horarios, características…): solo preguntas y ' \
                 'calificas. Si pregunta algo, o escribe algo que no tiene que ver con el negocio, dile con amabilidad que un ' \
                 'asesor se lo resuelve en cuanto lo atienda y, en el mismo mensaje, sigue con la pregunta pendiente. No ' \
                 'inventes nada.'
    },
    'not_found' => {
      'advisor' => 'Si buscas y no encuentras el dato, dile que no lo tienes a la mano y que un asesor se lo confirma, y sigue ' \
                   'con la pregunta pendiente. No lo pases a una persona solo por eso.',
      'silent' => 'Si buscas y no encuentras el dato, dile con naturalidad que no tienes ese dato y sigue con la pregunta ' \
                  'pendiente. No prometas que un asesor se lo confirma ni lo pases a una persona por eso.'
    },
    'off_topic' => {
      'redirect' => 'Si escribe algo que no tiene que ver con el negocio (EL NEGOCIO), no lo contestes: regrésalo con ' \
                    'amabilidad a la plática y sigue con la pregunta pendiente.',
      'answer' => 'Si escribe algo que no tiene que ver con el negocio (EL NEGOCIO), contéstale con amabilidad en 1 o 2 líneas ' \
                  '(sin buscar en tus fuentes ni inventar datos) y sigue con la pregunta pendiente.'
    },
    'human' => {
      'finish_first' => 'Si pide hablar con una persona: dile que con gusto lo pasas con un asesor y que, para que lo atienda ' \
                        "mejor, solo te faltan unas preguntas (como máximo #{MAX_BEFORE_HUMAN}); hazlas. Si lo vuelve a pedir o " \
                        'se molesta, pásalo YA con pasar_a_humano, sin más preguntas.',
      'now' => 'Si pide hablar con una persona, pásalo de inmediato con pasar_a_humano y despídete diciendo que en un momento ' \
               'lo atiende un asesor.'
    }
  }.freeze

  module_function

  # La opción elegida (o la recomendada). Los valores de antes pasan a la recomendada.
  def choice(answers, rule)
    value = answers.to_h[rule].to_s
    value = LEGACY.dig(rule, value) || value
    value.presence_in(OPTIONS[rule]) || OPTIONS[rule].first
  end

  def choices(answers) = OPTIONS.keys.index_with { |rule| choice(answers, rule) }

  # Para guardar: solo valores conocidos.
  def sanitize(raw) = OPTIONS.keys.index_with { |rule| choice(raw, rule) }

  # Las reglas que aplican: sin contestar dudas, «no encontró» y «fuera de tema» no cuentan.
  def active(answers)
    picked = choices(answers)
    answers_doubts?(answers) ? picked : picked.except(*NEEDS_DOUBTS)
  end

  def block(answers)
    "CÓMO PLATICAS (lo eligió la empresa; manda sobre lo anterior):\n" \
      "#{active(answers).map { |rule, value| "- #{RULES[rule][value]}" }.join("\n")}"
  end

  # Sin contestar dudas no hay búsqueda: el agente no tiene con qué buscar.
  def answers_doubts?(answers) = choice(answers, 'doubts') == 'answer'

  def human_now?(answers) = choice(answers, 'human') == 'now'
end
