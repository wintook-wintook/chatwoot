# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — TEMAS → RUTAS, AGRUPADOS (M3 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Cada tema de la ficha se vuelve una ruta. Con ADAM (29/09/2026) fueron 52, varias no
# eran algo que el CLIENTE viene a pedir sino etapas del agente («Concluir una
# intervención», «Duplicidad de información»). La regla 4 del lector ya lo prohíbe, pero
# con 74 trozos se cuela.
#
# Con más de MAX_ROUTES temas, la IA los agrupa por intención del cliente:
#
#   51 temas ─► grupos (≤ MAX_ROUTES): nombre · frases del cliente · qué hace · los temas
#               que junta (por número)
#
# Lo que la IA no devuelve en ningún grupo NO se pierde: vuelve como tema suelto (si con
# eso se pasa del tope, igual se ve en el modal y la persona decide). Las etapas internas
# que la IA marque van a «que_hace» del grupo que la usa. Sin respuesta, la ficha queda
# como estaba.
# ================================================================================

class ContactTrackings::Assistant::BriefTopicGroups
  Ficha = ContactTrackings::Assistant::BriefFicha

  MAX_ROUTES = 20
  MAX_OUTPUT_TOKENS = 8_000

  PROMPT = <<~PROMPT
    Recibes los temas numerados de las instrucciones de un agente de IA que atiende clientes
    por chat. Cada grupo que armes será UNA ruta: algo que el CLIENTE viene a pedir o a
    resolver (preguntar un precio, pedir una página web, poner una objeción, agendar).

    1. Junta en un grupo los temas que el cliente pediría con las mismas palabras o que el
       agente atiende igual. Máximo %<max>d grupos.
    2. Un tema que es una etapa o regla interna del agente (cerrar una intervención, evitar
       duplicar información, medir indicadores) NO es un grupo: ponlo en "internos" del grupo
       donde el agente lo usa.
    3. Cada tema (por su número) va en exactamente un grupo, en "temas" o en "internos".
    4. "nombre": corto, en minúsculas y con guiones bajos (desarrollo_web). "frases": hasta 6,
       tal como escribiría el cliente, sacadas de los temas (no inventes). "que_hace": una
       línea con lo que hace el agente en ese grupo.

    Contesta SOLO el JSON:
    {"grupos": [{"nombre": "…", "frases": ["…"], "que_hace": "…", "temas": [1, 4], "internos": [7]}]}
  PROMPT

  def initialize(account, ficha:)
    @account = account
    @ficha = ficha
  end

  # { ficha:, usage:, antes:, despues: }
  def call
    temas = Array(@ficha['temas'])
    return result(@ficha, {}, temas.size) if temas.size <= MAX_ROUTES

    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    raw = chat.call([{ role: 'system', content: format(PROMPT, max: MAX_ROUTES) },
                     { role: 'user', content: numbered(temas).to_json }], max_tokens: MAX_OUTPUT_TOKENS, temperature: 0.0)
    grupos = groups_from(raw, temas)
    return result(@ficha, chat.last_usage, temas.size) if grupos.empty?

    ficha = @ficha.deep_dup.merge('temas' => grupos + leftovers(grupos, temas))
    result(ficha, chat.last_usage, temas.size)
  end

  private

  def numbered(temas)
    temas.each_with_index.map do |t, i|
      { 'n' => i + 1, 'nombre' => t['nombre'], 'frases' => t['frases_cliente'], 'que_hace' => t['que_hace'] }.compact
    end
  end

  def groups_from(raw, temas)
    usados = Set.new
    Array(raw.is_a?(Hash) ? raw['grupos'] : nil).filter_map do |g|
      propios = indexes(g['temas'], temas, usados)
      internos = indexes(g['internos'], temas, usados)
      next if propios.empty? || g['nombre'].blank?

      topic(g, propios.map { |i| temas[i] }, internos.map { |i| temas[i] })
    end
  end

  # Números válidos (1..n) que ningún grupo anterior tomó.
  def indexes(numeros, temas, usados)
    Array(numeros).filter_map do |n|
      i = n.to_i - 1
      next unless i.between?(0, temas.size - 1) && usados.add?(i)

      i
    end
  end

  # El grupo como un tema de la ficha. Fuente, escalamiento y etiqueta: los del primer tema
  # que los traiga (los del encargo, no los de la IA).
  def topic(grupo, propios, internos)
    todos = propios + internos
    { 'nombre' => grupo['nombre'].to_s.squish, 'frases_cliente' => phrases(grupo, propios),
      'que_hace' => what_it_does(grupo, internos), 'fuente' => first_of(propios, 'fuente'),
      'si_no_resuelve' => first_of(propios, 'si_no_resuelve'), 'etiqueta' => first_of(propios, 'etiqueta'),
      'junta' => todos.pluck('nombre'), 'origen' => todos.flat_map { |t| Array(t['origen']) }.uniq.sort }.compact_blank
  end

  # Las de la IA; si no dio ninguna, las de los temas que junta.
  def phrases(grupo, propios)
    frases = Array(grupo['frases']).map { |f| Ficha.short(f) }.compact_blank.presence ||
             propios.flat_map { |t| Array(t['frases_cliente']) }
    frases.uniq.first(Ficha::MAX_PHRASES)
  end

  def what_it_does(grupo, internos)
    Ficha.short([grupo['que_hace'], *internos.map { |t| t['que_hace'] || t['nombre'] }].compact_blank.join(' · '))
  end

  def first_of(temas, campo) = temas.pluck(campo).compact_blank.first

  # Los temas que la IA no puso en ningún grupo vuelven tal cual.
  def leftovers(grupos, temas)
    juntados = grupos.flat_map { |g| Array(g['junta']) }.to_set
    temas.reject { |t| juntados.include?(t['nombre']) }
  end

  def result(ficha, usage, antes)
    { ficha: ficha, usage: usage.to_h, antes: antes, despues: Array(ficha['temas']).size }
  end
end
