# frozen_string_literal: true

# ================================================================================
# proyecto@importar_prompt_md — F1: REPARTIR
# ================================================================================
# Plan: docs/importar_prompt_md_plan.md (§4.2). Decide A DÓNDE va cada parte del .md que
# leyó el Reader. La unidad es la sección (el "##" que agrupa una Norma y su Texto
# oficial); en un prompt común, sin reglas, cada título de primer y segundo nivel.
#
#   section    reglas que valen en todos los mensajes          → Secciones del Entrenamiento
#   route      reglas de un tema (precios, objeciones, cierre)  → Ruta + su alcance
#   knowledge  lo que se consulta cuando hace falta             → Respuestas predefinidas
#   script     un guion de varios mensajes                      → Respuesta predefinida con
#                                                                 "El mensaje es el prompt"
#   out        lo que no es para la conversación                → Fuera, con su motivo
#
# DOS PASOS:
#   1. Reglas fijas por título (gratis, instantáneas). Dan un destino y una PISTA: el tema
#      de la ruta ("precios") o el nombre de la sección ("ROL").
#   2. La IA revisa TODAS las unidades de una vez, pero solo con título, descripción y tres
#      reglas de muestra, no con el texto: en ADAM son 81 secciones, una sola llamada de
#      ≈ 25 s. Las reglas fijas aciertan lo obvio pero no el criterio: "Diagnóstico
#      Ejecutivo" suena a sección y es trabajo del consultor en sesión, no del agente. Por
#      eso la IA ve todo, y no solo lo que las reglas fijas no resolvieron (el plan decía
#      eso; revisar todo cuesta centavos).
#
# Lo que pregunta la IA y quién gana cuando no coincide con las reglas fijas: AiReview.
#
# Sin integración de OpenAI, o si la llamada falla, queda el reparto de las reglas fijas
# y se avisa (ai[:status]): nada se pierde, solo falta la revisión.
#
# Lo que el reparto decide NO es final: la vista previa (F5) deja mover cada unidad.
# ================================================================================
class ContactTrackings::PromptImport::Distributor
  DESTINATIONS = %w[section route knowledge script out].freeze
  SAMPLE_RULES = 3

  # Reglas fijas, en orden: gana la primera que coincide con el título de la sección (o,
  # en su defecto, del capítulo). Los títulos se comparan sin tildes ni mayúsculas y SIN
  # el subtítulo que va después de "—": en ADAM, "Seguimiento — …y el cierre elegante"
  # caía en la ruta de reunión por "cierre", y "Conducción a la reunión — …la cotización…"
  # en la de precios.
  FIXED = [
    [/\b(portada|indice|tabla de contenido|historial de versiones|continuacion editorial)\b/, 'out', nil],
    [/\bguion\b/, 'script', nil],
    [/\b(glosario|analogias?|errores (estrategicos|frecuentes)|preguntas frecuentes|faq)\b/, 'knowledge', 'glosario'],
    [/\bobjecion/, 'route', 'objeciones'],
    [/\b(precios?|tarifas?|cotizacion|polizas?|bonificacion|negociacion|descuentos?)\b/, 'route', 'precios'],
    [/\b(escalamiento|derivacion)\b/, 'route', 'escalamiento'],
    [/\b(reunion|cierre|conduccion|agenda|cita|correo)\b/, 'route', 'reunion'],
    [/\bpresentacion de la (agencia|empresa)\b/, 'route', 'servicios'],
    [/\b(identidad|rol|quien eres|mision|proposito)\b/, 'section', 'ROL'],
    [/\b(principios|valores|reglas|etica|nunca|prohibiciones)\b/, 'section', 'PRINCIPIOS'],
    [/\b(lenguaje|terminologia|diccionario|definiciones|terminos)\b/, 'section', 'LENGUAJE'],
    [/\b(diagnostic|hipotesis|evidencia|confirmacion|recomendar)/, 'section', 'DIAGNOSTICO'],
    [/\b(conversa|escucha|empatia|comunicacion|confianza|persuasion|temperatura|tono|estilo)/, 'section',
     'CONVERSACION'],
    [/\b(oferta|servicios?|catalogo|productos?)\b/, 'knowledge', 'servicio']
  ].freeze

  # fixed: el destino que dieron las reglas fijas, para mostrar en la vista previa cuando
  # la IA lo cambió.
  Unit = Struct.new(:key, :chapter, :title, :excerpt, :rule_ids, :severities, :chars, :samples,
                    :destination, :hint, :source, :reason, :fixed, keyword_init: true)
  Result = Struct.new(:units, :tests, :out_blocks, :ai, keyword_init: true) do
    def by_destination
      units.group_by(&:destination).transform_values(&:size)
    end
  end

  def initialize(read, account: nil, use_ai: true)
    @read = read
    @account = account
    @use_ai = use_ai && account.present?
  end

  def call
    units = build_units
    units.each { |unit| apply_fixed(unit) }
    ai = @use_ai ? ContactTrackings::PromptImport::AiReview.new(units, account: @account).call : { status: :skipped }
    Result.new(units: units, tests: test_blocks, out_blocks: cover_blocks, ai: ai)
  end

  private

  # ------------------------------------------------------------------ unidades

  def build_units
    @read.format == :rules ? rule_units : block_units
  end

  # Una unidad por sección "##" que tenga reglas: sus reglas + el tamaño de todo lo que
  # cuelga de ella (Norma y Texto oficial).
  def rule_units
    @read.rules.group_by { |r| r.path.first(2) }.map.with_index do |((chapter, title), rules), i|
      section = section_block(chapter, title)
      Unit.new(key: "u#{i + 1}", chapter: chapter, title: title, excerpt: section&.excerpt.to_s,
               rule_ids: rules.map(&:id), severities: rules.map(&:severity).tally,
               chars: subtree_chars(section), samples: samples(rules))
    end
  end

  # Sin reglas: cada título de nivel 1 y 2 (los de más abajo viajan con su padre).
  def block_units
    tops = @read.blocks.select { |b| b.level <= [@read.blocks.map(&:level).min.to_i + 1, 2].max }
    tops.map.with_index do |block, i|
      Unit.new(key: "u#{i + 1}", chapter: block.path.first, title: block.title, excerpt: block.excerpt.to_s,
               rule_ids: [], severities: {}, chars: block.chars, samples: [])
    end
  end

  def section_block(chapter, title)
    @read.blocks.find { |b| b.path.first(2) == [chapter, title] && b.path.size == 2 }
  end

  def subtree_chars(section)
    return 0 unless section

    @read.blocks.select { |b| b.path.first(2) == section.path }.sum(&:chars)
  end

  # Las más fuertes primero: lo inviolable dice más de qué es la sección que lo recomendado.
  def samples(rules)
    order = %w[inviolable obligatoria recomendada]
    rules.sort_by { |r| order.index(r.severity) || order.size }.first(SAMPLE_RULES).map { |r| r.prompt.presence || r.text }
  end

  # ------------------------------------------------------------- reglas fijas

  def apply_fixed(unit)
    match = fixed_for(main_title(unit.title)) || fixed_for(main_title(unit.chapter))
    destination, hint = match || ['section', nil]
    unit.destination = destination
    unit.fixed = destination
    unit.hint = hint
    unit.source = match ? :fixed : :default
    unit.reason = match ? 'regla fija por título' : 'sin regla fija: sección por defecto'
  end

  def fixed_for(text)
    FIXED.find { |re, _, _| text.match?(re) }&.drop(1)
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase
  end

  def main_title(text)
    normalize(text.to_s.split(/\s+[—–]\s+/).first)
  end

  # ------------------------------------------------------------- otros bloques

  # "Aplicación práctica" y "Caso N": ejemplos de conversación → pruebas sugeridas (F7).
  def test_blocks
    @read.blocks.select { |b| normalize(b.title).match?(/\A(aplicacion practica|caso \d+)\b/) }.map(&:index)
  end

  # Lo que queda antes del primer capítulo con reglas (portada, créditos): fuera.
  def cover_blocks
    first_rule_chapter = @read.rules.first&.path&.first
    return [] unless first_rule_chapter

    @read.blocks.take_while { |b| b.path.first != first_rule_chapter }.map(&:index)
  end
end
