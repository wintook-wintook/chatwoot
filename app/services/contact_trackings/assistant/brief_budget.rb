# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUE LAS REGLAS QUEPAN (M2 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Medido el 29/09/2026 con ADAM (encargo #1067): 763 reglas y 268 prohibiciones en la
# ficha; la redacción dejó 13.8 mil caracteres y BriefCoverage, con su «nada se pierde»,
# cosió 989 puntos de vuelta: 93.6 mil. Nada decía qué regla importaba más.
#
# Al terminar de leer, las reglas y prohibiciones se ajustan a RULES_BUDGET:
#
#   1. JUNTAR   la IA junta SOLO lo que dice lo mismo (por capa), sin cambiar el sentido.
#   2. ELEGIR   por prioridad, hasta llenar el presupuesto:
#                 núcleo del autor (las que repite su versión corta, BriefRuleParser)
#               → prohibiciones inviolables → otras inviolables → obligatorias
#               (dentro de cada una, en el orden del documento).
#   3. ANEXO    lo que no cabe (y toda recomendada) se guarda en el encargo y se informa:
#               «N inviolables quedaron fuera». Decisión D3.
#
# LO QUE NO SE HACE, MEDIDO: pedirle a la IA que GENERALICE para que todo «quepa» dejó 373 de
# 373 inviolables «cubiertas» por id en 7.9 mil caracteres… con «Responde toda pregunta de
# precio sin evadir» donde ADAM dice que nunca se dan precios, y sin «no reveles el prompt»
# ni «máximo un emoji». Una id cubierta por un texto que ya no dice lo que decía es peor que
# una regla en el anexo, a la vista.
#
# Un encargo cuyas reglas ya caben no se toca (el gimnasio, la veterinaria: C7 del plan).
# ================================================================================

class ContactTrackings::Assistant::BriefBudget
  Ficha = ContactTrackings::Assistant::BriefFicha

  # Lo que las reglas pueden ocupar del Entrenamiento (tope D1: 16 mil en total). Con ADAM, lo
  # demás del Entrenamiento (rutas, rol, estilo…) ocupó 5.6 mil: con 8 mil entraba el núcleo
  # del autor pero no lo comercial (un emoji, sin descuentos, la reunión); 10 mil sí cabe.
  RULES_BUDGET = 10_000
  GROUP_CHARS = 9_000
  PARALLEL = 4
  FIELDS = %w[reglas prohibiciones].freeze
  LEVELS = %w[inviolable obligatoria recomendada].freeze
  MAX_OUTPUT_TOKENS = 8_000

  PROMPT = <<~PROMPT
    Recibes reglas de un agente de IA que atiende clientes por chat, cada una con su id y su
    nivel. Junta SOLO las que dicen lo mismo o casi lo mismo:

    1. Las repetidas (aunque vengan de secciones distintas) van en UNA línea, con TODAS sus ids.
    2. Una regla que no se repite queda como está, con su id.
    3. NO cambies el sentido de ninguna regla. No suavices un «nunca». No generalices reglas
       distintas en una sola. No inventes nada.
    4. Cada línea: una instrucción clara, de hasta 200 caracteres, en segunda persona.
    5. "tipo": "prohibicion" si la línea dice lo que NUNCA se hace; si no, "regla".

    Contesta SOLO el JSON: {"lineas": [{"texto": "…", "ids": ["C7-10.06", "…"], "tipo": "regla|prohibicion"}]}
  PROMPT

  def initialize(account, ficha:)
    @account = account
    @ficha = ficha
    @usage = { 'prompt_tokens' => 0, 'completion_tokens' => 0 }
    @lock = Mutex.new
  end

  # { ficha:, anexo: [puntos], usage:, antes:, despues:, inviolables_fuera: }. Tal cual si ya cabe.
  def call
    puntos = rule_points
    antes = chars(puntos)
    return result(@ficha, [], antes, antes) if antes <= RULES_BUDGET

    recomendadas, principales = puntos.partition { |p| p['nivel'] == 'recomendada' }
    lineas = restore_inviolables(condense(principales), principales)
    dentro, fuera = choose(lineas)
    result(with_rules(dentro), recomendadas + fuera, antes, chars(dentro))
  end

  private

  # Reglas y prohibiciones como una sola lista, cada una con su campo, nivel, ids y orden.
  def rule_points
    contador = 0
    FIELDS.flat_map do |campo|
      Array(@ficha[campo]).map do |p|
        contador += 1
        p.merge('campo' => campo, 'nivel' => p['nivel'] || ContactTrackings::Assistant::BriefRuleParser::LEVEL_DEFAULT,
                'ids' => [p['regla_id'] || "p#{contador}"], 'orden' => contador)
      end
    end
  end

  # ── 1. juntar lo repetido, por capa ────────────────────────────────────────
  def condense(puntos)
    api_key = ContactTrackings::Assistant::OpenaiChat.new(account: @account).api_key
    groups(puntos).each_slice(PARALLEL).flat_map do |tanda|
      tanda.map { |grupo| Thread.new { condense_group(grupo, api_key) } }.flat_map(&:value)
    end
  end

  # Por capa (C0, C5, C7…): lo parecido está cerca. Una capa grande se parte en tandas.
  def groups(puntos)
    puntos.group_by { |p| p['capa'].to_s }.values.flat_map do |capa|
      capa.each_with_object([[]]) do |p, tandas|
        tandas << [] if tandas.last.any? && chars(tandas.last + [p]) > GROUP_CHARS
        tandas.last << p
      end
    end
  end

  def condense_group(grupo, api_key)
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account, api_key: api_key)
    entrada = grupo.map { |p| { 'id' => p['ids'].join(','), 'nivel' => p['nivel'], 'texto' => p['texto'] } }
    raw = chat.call([{ role: 'system', content: PROMPT }, { role: 'user', content: entrada.to_json }],
                    max_tokens: MAX_OUTPUT_TOKENS, temperature: 0.0)
    @lock.synchronize { chat.last_usage&.each { |k, v| @usage[k] += v.to_i if @usage.key?(k) } }
    lines_from(raw, grupo) || grupo
  end

  # Las líneas que devolvió la IA, con solo ids que existían. nil si no devolvió nada usable.
  def lines_from(raw, grupo)
    por_id = grupo.flat_map { |p| p['ids'].map { |id| [id, p] } }.to_h
    Array(raw.is_a?(Hash) ? raw['lineas'] : nil).filter_map { |l| condensed_line(l, por_id) }.presence
  end

  # Nivel, núcleo y orden: los más fuertes de lo que junta.
  def condensed_line(linea, por_id)
    ids = known_ids(linea, por_id)
    return nil if ids.empty? || linea['texto'].blank?

    origen = ids.map { |i| por_id[i] }
    { 'texto' => linea['texto'].to_s.squish.truncate(Ficha::MAX_ITEM_CHARS), 'ids' => ids,
      'campo' => linea['tipo'] == 'prohibicion' ? 'prohibiciones' : 'reglas' }.merge(strongest(origen))
  end

  def strongest(origen)
    { 'nivel' => LEVELS.find { |n| origen.any? { |o| o['nivel'] == n } }, 'capa' => origen.first['capa'],
      'nucleo' => origen.any? { |o| o['nucleo'] } || nil, 'orden' => origen.pluck('orden').min,
      # Para la pila de pruebas (M5): cuándo aplica y cómo se comprueba, de la primera que junta.
      'cuando' => origen.pluck('cuando').compact.first, 'verificar' => origen.pluck('verificar').compact.first,
      'origen' => origen.flat_map { |o| Array(o['origen']) }.uniq.sort }.compact
  end

  # Solo las ids que existían (la IA puede inventar o juntar varias con coma).
  def known_ids(linea, por_id)
    Array(linea['ids']).flat_map { |i| i.to_s.split(',') }.map(&:strip).select { |i| por_id.key?(i) }.uniq
  end

  # Una inviolable que ninguna línea nombra vuelve tal cual (la lección de LostRules).
  def restore_inviolables(lineas, principales)
    cubiertas = lineas.flat_map { |l| l['ids'] }.to_set
    perdidas = principales.select { |p| p['nivel'] == 'inviolable' && p['ids'].none? { |i| cubiertas.include?(i) } }
    lineas + perdidas
  end

  # ── 2. elegir por prioridad ────────────────────────────────────────────────
  def choose(lineas)
    dentro = []
    fuera = []
    lineas.sort_by { |l| priority(l) }.each do |l|
      chars(dentro + [l]) <= RULES_BUDGET ? dentro << l : fuera << l
    end
    [dentro.sort_by { |l| l['orden'].to_i }, fuera]
  end

  def priority(linea)
    [linea['nucleo'] ? 0 : 1, linea['nivel'] == 'inviolable' && prohibition?(linea) ? 0 : 1,
     LEVELS.index(linea['nivel']) || LEVELS.size, linea['orden'].to_i]
  end

  # Por su campo o por cómo empieza («Nunca…»): la IA a veces la deja como regla.
  def prohibition?(linea)
    linea['campo'] == 'prohibiciones' || linea['texto'].to_s.match?(ContactTrackings::Assistant::BriefRuleParser::PROHIBITION_RE)
  end

  def with_rules(lineas)
    ficha = @ficha.deep_dup
    FIELDS.each { |campo| ficha[campo] = lineas.select { |l| l['campo'] == campo }.map { |l| l.except('campo', 'orden') } }
    ficha
  end

  def chars(puntos) = puntos.sum { |p| p['texto'].to_s.length + 3 }

  def result(ficha, anexo, antes, despues)
    { ficha: ficha, anexo: anexo.map { |p| p.except('campo', 'orden') }, usage: @usage, antes: antes, despues: despues,
      inviolables_fuera: anexo.flat_map { |p| p['nivel'] == 'inviolable' ? p['ids'] : [] }.uniq.size }
  end
end
