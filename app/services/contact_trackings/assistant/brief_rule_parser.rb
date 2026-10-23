# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REGLAS NUMERADAS DEL ENCARGO, SIN IA (M1 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Hay encargos que ya son un reglamento: cada regla con su id, su nivel y su resumen.
# ADAM (29/09/2026) trae 818 así:
#
#   **C7-10.06** (inviolable) — No entregues importes, rangos ni referencias …
#     - Activación: Si el prospecto reitera la exigencia de un número concreto.
#     - Verificación: No aparece ninguna cifra y el caso queda derivado a dirección.
#     - Prompt: Nunca des importes ni rangos aunque insistan; escala a dirección …
#
# y su versión corta («- [C0-01.02] No finjas ser humano…», bajo «## C0 · CONSTITUCIÓN»).
# Leerlas con la IA costaba lectura y, al juntarlas, 25 llamadas que igual no cabían; y
# perdía el nivel, que es lo que decide qué entra al Entrenamiento (M2).
#
# Aquí se sacan con expresiones regulares: exactas, con su nivel, capa, cuándo aplican y
# cómo se comprueban. `masked` es el encargo con esos renglones en blanco (mismo número de
# renglones): lo que la IA todavía tiene que leer (temas, identidad, conocimiento).
#
# Solo se activa con MIN_RULES o más: un encargo común con un «**Nota** (importante)» suelto
# sigue el camino de siempre.
# ================================================================================

class ContactTrackings::Assistant::BriefRuleParser
  MIN_RULES = 20
  LEVELS = %w[inviolable obligatoria recomendada].freeze
  ID = '[A-Z][A-Z0-9]{0,4}-\d+(?:\.\d+)*'
  LONG_RE = /\A\s*\*\*(?<id>#{ID})\*\*\s*\((?<nivel>#{LEVELS.join('|')})\)\s*[—–-]+\s*(?<texto>.+?)\s*\z/io
  SHORT_RE = /\A\s*[-*]\s*\[(?<id>#{ID})\]\s*(?<texto>.+?)\s*\z/o
  FIELD_RE = /\A\s+[-*]\s*(?<campo>Activaci[oó]n|Verificaci[oó]n|Prompt)\s*:\s*(?<valor>.+?)\s*\z/i
  LAYER_RE = /\A\#{1,2}\s+(?<capa>C\d+\s*·\s*.+?)\s*\z/
  HEADING_RE = /\A(?<marks>\#{2,3})\s+(?<titulo>.+?)\s*\z/
  PROHIBITION_RE = /\A\s*(nunca|no\s|jam[aá]s|prohibid|evita\s)/i

  # Sin nivel en el texto (la versión corta) cuenta como obligatoria.
  LEVEL_DEFAULT = 'obligatoria'

  # nucleo: la regla también está en la versión corta. Ahí el autor elige las que van al
  # prompt (el «Perfil: Núcleo · 71 reglas activas» de ADAM): pasan primero (BriefBudget).
  Rule = Struct.new(:id, :nivel, :capa, :seccion, :texto, :completo, :cuando, :verificar, :linea, :nucleo,
                    keyword_init: true) do
    def prohibicion? = texto.match?(PROHIBITION_RE)

    # Como punto de la ficha: lo que la IA no sabría decir (id, nivel, capa, cómo se comprueba).
    def to_point(origin: [])
      corto = ->(v) { v.presence && ContactTrackings::Assistant::BriefFicha.short(v) }
      { 'texto' => corto.call(texto), 'regla_id' => id, 'nivel' => nivel || LEVEL_DEFAULT, 'capa' => capa,
        'cuando' => corto.call(cuando), 'verificar' => corto.call(verificar), 'nucleo' => nucleo || nil,
        'origen' => origin }.compact
    end
  end
  Result = Struct.new(:rules, :masked, keyword_init: true) do
    def structured? = rules.size >= MIN_RULES
  end

  def self.call(text)
    new(text).call
  end

  def initialize(text)
    @lines = text.to_s.split("\n", -1)
    @cortas = Set.new
  end

  def call
    reglas = {}
    tapados = Set.new
    capa = nil
    seccion = nil
    @lines.each_with_index do |linea, n|
      if (m = linea.match(LAYER_RE)) then capa = m[:capa].squish
      elsif (m = linea.match(HEADING_RE)) && !linea.match?(LAYER_RE) then seccion = m[:titulo].squish
      end
      regla = rule_at(linea, n, capa, seccion, tapados)
      keep(reglas, regla) if regla
    end
    reglas.each_value { |r| r.nucleo = @cortas.include?(r.id) }
    Result.new(rules: reglas.values, masked: masked_text(tapados))
  end

  private

  # La regla que empieza en el renglón n (con sus campos de abajo), o nil.
  def rule_at(linea, numero, capa, seccion, tapados)
    if (m = linea.match(LONG_RE))
      campos = fields_below(numero, tapados)
      tapados << numero
      Rule.new(id: m[:id], nivel: m[:nivel].downcase, capa: capa, seccion: seccion, completo: m[:texto],
               texto: campos['prompt'] || m[:texto], cuando: campos['activacion'], verificar: campos['verificacion'],
               linea: numero + 1)
    elsif (m = linea.match(SHORT_RE))
      @cortas << m[:id]
      tapados << numero
      Rule.new(id: m[:id], nivel: nil, capa: capa, seccion: seccion, texto: m[:texto], completo: m[:texto], linea: numero + 1)
    end
  end

  def fields_below(numero, tapados)
    campos = {}
    (numero + 1...@lines.size).each do |n|
      m = @lines[n].match(FIELD_RE)
      break unless m

      campos[I18n.transliterate(m[:campo]).downcase] = m[:valor]
      tapados << n
    end
    campos
  end

  # La versión larga manda (trae nivel y verificación); la corta solo llena lo que falte.
  def keep(reglas, nueva)
    vieja = reglas[nueva.id]
    return reglas[nueva.id] = nueva if vieja.nil?
    return if nueva.nivel.nil?

    reglas[nueva.id] = nueva.nivel && vieja.nivel.nil? ? nueva : vieja
  end

  def masked_text(tapados)
    @lines.each_with_index.map { |linea, n| tapados.include?(n) ? '' : linea }.join("\n")
  end
end
