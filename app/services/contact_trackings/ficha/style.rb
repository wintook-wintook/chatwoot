# frozen_string_literal: true

# ================================================================================
# feat/tono_editable_asistente — EL [ESTILO] DEL AGENTE: TRATO, TONO Y AJUSTES
# ================================================================================
# Pedido del usuario (13/11/2026): «que se pueda cambiar el tono en cualquier momento en el
# asistente… cuando creo uno nuevo sí aparece el tono, pero ya creado al editar ya no». Y
# los 5 tonos eran siempre de tú: un agente de usted (cuenta 613) no se podía crear así.
#
# Trato (tú | usted) + tono (uno de TONE_PHRASES) + ajustes (emojis, muy cortas, pregunta):
#
#   [ESTILO]
#   Hablo de usted, en español de México, con un tono profesional, amable y serio. Respuestas
#   cortas y claras, de máximo 4 líneas, salvo la lista del catálogo. Sin emojis. Las ligas van
#   como texto simple…
#
# .read  saca de [ESTILO] lo que reconoce (nil donde el texto es propio).
# .write cambia SOLO lo que se pidió y deja lo demás como lo escribió la persona: en el
#        ejemplo, pasar a «muy cortas» conserva «, salvo la lista del catálogo» y «Las ligas
#        van como texto simple…». Sin [ESTILO], lo crea completo.
# ================================================================================

module ContactTrackings::Ficha::Style
  TRATOS = %w[tu usted].freeze
  # Lo que sigue a «Hablo de tú/usted, » en cada tono.
  TONE_PHRASES = {
    'cercano' => 'en español de México, cálido y cercano, como alguien del negocio.',
    'profesional' => 'en español de México, con un tono profesional, amable y serio.',
    'entusiasta' => 'en español de México, con energía y entusiasmo; invito al cliente a dar el siguiente paso ' \
                    'sin presionarlo.',
    'empatico' => 'en español de México, con empatía: si el cliente tiene un problema o una molestia, primero ' \
                  'lo reconozco y luego lo ayudo a resolverlo.',
    'directo' => 'en español de México, directo y sin rodeos: digo lo necesario.'
  }.freeze
  SHORT = 'Respuestas muy cortas: máximo 2 líneas'
  NORMAL = 'Respuestas cortas y claras, de máximo 4 líneas'
  EMOJIS = 'Uso uno o dos emojis cuando ayudan; nunca de más.'
  NO_EMOJIS = 'Sin emojis.'
  QUESTION = 'Cierro con una pregunta sencilla para seguir la plática.'
  ADJUSTS = %w[emojis short question].freeze

  SECTION_RE = ContactTrackings::Assistant::DraftPieces::SECTION_RE
  TRATO_RE = /Hablo de (tú|tu|usted)\b/i
  TONE_SENTENCE_RE = /Hablo de (?:tú|tu|usted), (?:#{TONE_PHRASES.values.map { |f| Regexp.escape(f) }.join('|')})/io

  module_function

  def trato_word(trato) = trato.to_s == 'usted' ? 'usted' : 'tú'

  def tone_sentence(trato, tone) = "Hablo de #{trato_word(trato)}, #{TONE_PHRASES.fetch(tone.to_s, TONE_PHRASES['cercano'])}"

  # El texto completo de [ESTILO] (sin el rótulo), como lo escribe el Generator.
  def body(trato, tone, adjust)
    lineas = [tone_sentence(trato, tone), "#{adjust['short'] ? SHORT : NORMAL}.", adjust['emojis'] ? EMOJIS : NO_EMOJIS]
    lineas << QUESTION if adjust['question']
    lineas.join(' ')
  end

  # { trato: 'tu'|'usted'|nil, tone: 'cercano'…|nil, tone_adjust: {…}, text: cuerpo|nil }
  def read(prompt)
    cuerpo = section_body(prompt.to_s.split("\n", -1))
    return { trato: nil, tone: nil, tone_adjust: nil, text: nil } if cuerpo.nil?

    { trato: read_trato(cuerpo), tone: read_tone(cuerpo), text: cuerpo.strip,
      tone_adjust: { 'emojis' => cuerpo.include?(EMOJIS), 'short' => cuerpo.include?(SHORT),
                     'question' => cuerpo.include?(QUESTION) } }
  end

  def read_trato(cuerpo)
    palabra = cuerpo[TRATO_RE, 1]
    palabra && (palabra.casecmp?('usted') ? 'usted' : 'tu')
  end

  def read_tone(cuerpo)
    TONE_PHRASES.find { |_, frase| cuerpo.include?(frase) }&.first
  end

  # Lo que pide la pantalla (todo, cambie o no) → el prompt con SOLO lo que cambió escrito.
  def update(prompt, **pedido) = ContactTrackings::Ficha::StyleEditor.update(prompt, **pedido)

  def write(prompt, **cambios) = ContactTrackings::Ficha::StyleEditor.write(prompt, **cambios)

  def section_range(lineas)
    inicio = lineas.index { |l| (m = l.match(SECTION_RE)) && m[1].strip.casecmp?('ESTILO') }
    return nil if inicio.nil?

    fin = ((inicio + 1)...lineas.size).find { |i| lineas[i].match?(SECTION_RE) } || lineas.size
    [inicio, fin]
  end

  def section_body(lineas)
    rango = section_range(lineas)
    rango && lineas[(rango[0] + 1)...rango[1]].join("\n")
  end
end
