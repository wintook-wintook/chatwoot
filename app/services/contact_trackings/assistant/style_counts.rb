# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE EL JUEZ CUENTA SIN IA (P2 · 3.4a)
# ================================================================================
# En F0 (13/10/2026) el juez con IA reprobó 40 de 43 respuestas casi siempre por «dos
# preguntas en un mensaje», y contadas a mano solo 1 de 129 las tenía. También dijo «termina
# en afirmación» de respuestas que terminaban en «?». Lo que se puede contar no se le pregunta
# a la IA: se lee del [ESTILO] y se mide en lo que escribió el agente (ReplyParts#body).
#
# Del [ESTILO] salen, si las dice:
#   preguntas   «una sola pregunta (por mensaje | a la vez)»     «preferentemente…» = aviso, no falla
#   cierre      «cierra con una pregunta», «al final como cierre»
#   renglones   «2 a 4 líneas», «máximo 4 líneas»                 «no aplica a procedimientos» = los pasos no cuentan
#   párrafos    «máximo cuatro párrafos», «hasta cuatro párrafos»
#   emojis      «máximo un emoji», «1 o 2 emojis», «sin emojis»
#
# RENGLÓN: cada línea escrita cuenta, y una línea larga cuenta como varios renglones de
# ~100 caracteres: un párrafo de 400 caracteres en una sola línea no son «2 a 4 líneas».
# Los mínimos («2 a…») no se exigen: una respuesta corta no rompe el estilo.
# Lo que no se cuenta (tú o usted, el tono, dos preguntas juntas en una sola con «y») lo
# sigue calificando la IA.
# ================================================================================

class ContactTrackings::Assistant::StyleCounts
  RENGLON = 100
  NUM = '(\d+|un|una|uno|dos|tres|cuatro|cinco|seis)'
  WORDS = { 'un' => 1, 'una' => 1, 'uno' => 1, 'dos' => 2, 'tres' => 3, 'cuatro' => 4, 'cinco' => 5, 'seis' => 6 }.freeze
  EMOJI_RE = /\p{Extended_Pictographic}/
  NOT_EMOJI_RE = /\A[©®™]\z/ # son Extended_Pictographic, pero en «Sentidos Creativos®» no son emoji
  STEP_RE = /\A\s*(?:\d+[.)]|\d️?⃣|[-*•])\s/
  URL_RE = %r{https?://\S+}

  PATTERNS = {
    'preguntas' => [/\buna sola pregunta\b|\bsolo una pregunta\b|\buna pregunta (?:principal )?(?:por|a la) (?:mensaje|turno|vez)\b/,
                    ->(_m) { 1 }],
    'cierre' => [/\b(?:cierra|cierre|termina|terminar)\b[^.]{0,50}\bpregunta\b|\bpregunta\b[^.]{0,30}\bal final\b|\bcomo cierre\b/, ->(_m) { true }],
    'renglones' => [/#{NUM}\s*(?:a|-|o)\s*#{NUM}\s*lineas\b|(?:maximo|hasta)\s*#{NUM}\s*lineas\b/,
                    ->(m) { number(m[2] || m[3]) }],
    'parrafos' => [/(?:maximo|hasta)\s*#{NUM}\s*parrafos\b/, ->(m) { number(m[1]) }],
    'emojis' => [/#{NUM}\s*(?:o|a|-)\s*#{NUM}\s*emojis?\b|(?:maximo|hasta)\s*#{NUM}\s*emojis?\b|\b(?:sin|ningun|cero) emojis?\b(?! en)/,
                 ->(m) { number(m[2] || m[3] || '0') }]
  }.freeze

  # Qué oraciones del [ESTILO] hablan de lo que se cuenta.
  TOPICS = { 'preguntas' => [/\bpreguntas?\b/], 'cierre' => [/\bpreguntas?\b/, /\btermin|\bcierr|\bcierra/],
             'renglones' => [/\blineas?\b|\brenglon/], 'parrafos' => [/\bparrafos?\b/], 'emojis' => [/\bemojis?\b/] }.freeze

  # { 'preguntas' => { 'max' => 1, 'soft' => false, 'texto' => '…' }, … }
  attr_reader :rules

  def self.number(texto) = WORDS[texto] || texto.to_i

  def initialize(estilo)
    @estilo = estilo.to_s
    @rules = parse
    @steps_exempt = normalize(@estilo).match?(/no aplica a (?:los )?procedimientos|pasos van completos/)
  end

  def any? = @rules.any?

  # El [ESTILO] sin las oraciones de lo que se cuenta, para la IA: con «Nunca juntes dos preguntas»
  # a la vista, la IA siguió contando preguntas aunque se le prohibió (3.4a, 13/10/2026).
  def uncounted
    temas = @rules.keys.flat_map { |clave| TOPICS[clave] }
    oraciones(@estilo).reject { |o| temas.any? { |t| normalize(o).match?(t) } }.join("\n")
  end

  # { medidas:, fallas: [], avisos: [] } — sin texto del agente no hay nada que medir.
  def call(body)
    texto = body.to_s.gsub(URL_RE, '').strip
    return { medidas: {}, fallas: [], avisos: [] } if texto.empty?

    medidas = measure(texto)
    salida = { medidas: medidas, fallas: [], avisos: [] }
    @rules.each do |clave, regla|
      motivo = send("check_#{clave}", medidas, regla['max'])
      next if motivo.nil?

      (regla['soft'] ? salida[:avisos] : salida[:fallas]) << "#{motivo} (su [ESTILO]: «#{regla['texto'].truncate(80)}»)."
    end
    salida
  end

  private

  def parse
    oraciones(@estilo).each_with_object({}) do |oracion, reglas|
      normal = normalize(oracion)
      PATTERNS.each do |clave, (re, valor)|
        next if reglas.key?(clave) || (m = normal.match(re)).nil?

        reglas[clave] = { 'max' => valor.call(m), 'soft' => soft?(normal, m), 'texto' => oracion.strip }
      end
    end
  end

  # «preferentemente UNA pregunta» es aviso; el «máximo 1–2 emojis» de antes en la misma oración, no.
  def soft?(normal, match) = normal[[match.begin(0) - 25, 0].max...match.begin(0)].include?('preferente')

  def oraciones(texto) = texto.split(/(?<=[.;])\s+|\n+/).map(&:strip).reject(&:empty?)

  # Sin acentos ni mayúsculas; guiones largos a «-» («2–4 líneas»).
  def normalize(texto) = I18n.transliterate(texto.tr('–—', '--').downcase)

  def measure(texto)
    lineas = texto.lines.map(&:strip).reject(&:empty?)
    { 'preguntas' => texto.scan(/\?+/).size,
      'termina_en_pregunta' => texto.match?(/\?[\s\p{Extended_Pictographic}\uFE0F\u200D]*\z/),
      'renglones' => lineas.sum { |l| (l.length / RENGLON.to_f).ceil },
      'parrafos' => texto.split(/\n[ \t]*\n/).count { |p| p.strip.present? },
      'emojis' => emojis(texto),
      'pasos' => lineas.count { |l| l.match?(STEP_RE) },
      'caracteres' => texto.length }
  end

  def emojis(texto) = texto.scan(/\X/).count { |g| g.match?(EMOJI_RE) && !g.match?(NOT_EMOJI_RE) }

  def check_preguntas(medidas, max)
    "Hace #{medidas['preguntas']} preguntas" if medidas['preguntas'] > max
  end

  def check_cierre(medidas, _max)
    'No termina en pregunta' unless medidas['termina_en_pregunta']
  end

  def check_renglones(medidas, max)
    return nil if medidas['renglones'] <= max
    return nil if @steps_exempt && medidas['pasos'] >= 2

    "Ocupa #{medidas['renglones']} renglones (de ~#{RENGLON} caracteres) y el máximo es #{max}"
  end

  def check_parrafos(medidas, max)
    "Tiene #{medidas['parrafos']} párrafos y el máximo es #{max}" if medidas['parrafos'] > max
  end

  def check_emojis(medidas, max)
    "Trae #{medidas['emojis']} emojis y el máximo es #{max}" if medidas['emojis'] > max
  end
end
