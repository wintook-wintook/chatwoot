# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — JUNTAR LAS FICHAS DE UN ENCARGO (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Una ficha por trozo (BriefReader) → UNA ficha del encargo. El modelo une lo repetido
# y anota las contradicciones entre partes; no las resuelve (las decide la persona en
# el chat). Un encargo de un solo trozo no llama al modelo.
#
# POR FAMILIAS, EN TANDAS CHICAS Y EN PARALELO. Medido el 23/09 con ADAM (73 trozos:
# 811 reglas, 325 prohibiciones, 138 puntos de conocimiento): juntar tandas de 60.000,
# 30.000 y hasta 24.000 caracteres pedía respuestas tan largas que se cortaban por
# max_tokens o pasaban los 180 s de espera (~1 min por tanda de 24.000). Ahora cada
# FAMILIA se junta aparte (FAMILIES), las cuatro a la vez, en tandas de MAX_INPUT_CHARS
# que corren de a GROUP_PARALLEL; las tandas se vuelven a juntar hasta que la familia
# entra en una llamada. Reglas, prohibiciones y contradicciones van en la misma familia:
# es donde aparecen los choques ("nunca des precio" / "da el rango").
#
# UNA TANDA QUE FALLA NO TIRA TODO: se reintenta una vez y, si igual falla, sus puntos
# pasan sin juntar. La ficha queda más larga, pero la lectura ya pagada no se pierde.
#
# EL ORIGEN NO SE PIERDE: cada punto de entrada lleva un id; el modelo devuelve en cada
# punto juntado los ids que junta. Con eso el código sabe de qué trozos salió cada cosa.
#
# LO QUE EL MODELO NO PUEDE BORRAR: una prohibición o un tema de la entrada cuyo id no
# aparece en ningún punto de la salida se vuelve a agregar tal cual. Es la lección de
# LostRules: al "resumir", el modelo borra prohibiciones llamándolas redundantes.
#
# PRESUPUESTO: cada familia tiene su parte de lo que la conversación del Asistente carga
# cómoda (16.000 caracteres entre todas). Si una se pasa, UNA vuelta más pidiendo apretar.
# El encargo no se toca: queda entero.
# ================================================================================

class ContactTrackings::Assistant::BriefMerger
  Ficha = ContactTrackings::Assistant::BriefFicha

  FAMILIES = {
    'nucleo' => %w[identidad objetivo modo tono datos_a_pedir herramientas fuera dudas],
    'temas' => %w[temas],
    'normas' => %w[reglas prohibiciones contradicciones],
    'conocimiento' => %w[conocimiento]
  }.freeze
  BUDGET = { 'nucleo' => 3_000, 'temas' => 4_000, 'normas' => 7_000, 'conocimiento' => 2_000 }.freeze
  # Una familia que se pasa de su parte por más de esto se aprieta una vez.
  BUDGET_SLACK = 1.25
  MAX_INPUT_CHARS = 10_000
  GROUP_PARALLEL = 3
  ATTEMPTS = 2
  MAX_OUTPUT_TOKENS = 16_000
  # Una vuelta que no achica al menos esto no se repite: el modelo ya no junta más.
  MIN_SHRINK = 0.9
  GUARDED = %w[prohibiciones temas].freeze

  PROMPT = ContactTrackings::Assistant::BriefMergePrompt::PROMPT
  TIGHTEN = ContactTrackings::Assistant::BriefMergePrompt::TIGHTEN

  # partials: [{ ficha:, origin: }] — origin: { id => [índices de trozo] }
  def initialize(account, partials:, progress: nil)
    @account = account
    @partials = partials
    @progress = progress
    @usage = { 'prompt_tokens' => 0, 'completion_tokens' => 0 }
    @calls = 0
    @answered = 0
    @lock = Mutex.new
  end

  # { ficha:, usage:, calls: } o { error: }. La ficha lleva en cada punto "origen": los
  # índices de trozo de donde salió.
  def call
    return { ficha: with_origin(@partials.first), usage: @usage, calls: 0 } if @partials.one?

    entrada, origen = combined(@partials)
    resultados = merge_families(entrada, origen)
    # Sin una sola respuesta no hay ficha: son las lecturas pegadas, no un encargo leído.
    return failure if resultados.any?(&:nil?) || @answered.zero?

    final = { ficha: singles(resultados.pluck(:ficha).reduce({}, :merge)),
              origin: resultados.pluck(:origin).reduce({}, :merge) }
    { ficha: with_origin(final), usage: @usage, calls: @calls }
  end

  private

  # ── familias, en paralelo ─────────────────────────────────────────────────────
  def merge_families(entrada, origen)
    familias = FAMILIES.filter_map do |nombre, campos|
      parte = entrada.slice(*campos).compact_blank
      [nombre, parte] if parte.any?
    end
    api_key = ContactTrackings::Assistant::OpenaiChat.new(account: @account).api_key # los hilos no tocan la base
    hilos = familias.map { |nombre, parte| Thread.new { merge_family(nombre, parte, origen, api_key) } }
    hilos.map(&:value)
  end

  def merge_family(nombre, parte, origen, api_key)
    Thread.current[:brief_merger_chat] = chat_with(api_key)
    actual = { ficha: parte, origin: origen }
    vuelta = 0
    loop do
      grupos = split(actual[:ficha])
      break if grupos.one?

      nuevo = merge_groups(nombre, grupos, actual[:origin], vuelta += 1)
      return nil if nuevo.nil?

      encogio = Ficha.size(nuevo[:ficha]) <= Ficha.size(actual[:ficha]) * MIN_SHRINK
      actual = nuevo
      break unless encogio
    end
    finish_family(nombre, actual, vuelta)
  end

  # La familia ya entra en una llamada (o dejó de achicarse): se junta entera, y se
  # aprieta si se pasa de su parte. Si falla, queda como estaba.
  def finish_family(nombre, actual, vuelta)
    unica = merge_call(actual[:ficha], actual[:origin], "#{nombre}#{vuelta + 1}") || actual
    return unica if Ficha.size(unica[:ficha]) <= BUDGET[nombre] * BUDGET_SLACK

    merge_call(as_lists([unica[:ficha]]), unica[:origin], "#{nombre}#{vuelta + 2}", tighten: true) || unica
  end

  # Las tandas de una vuelta, de a GROUP_PARALLEL. Una que falla pasa sin juntar.
  def merge_groups(nombre, grupos, origen, vuelta)
    chat = Thread.current[:brief_merger_chat]
    resultados = grupos.each_with_index.each_slice(GROUP_PARALLEL).flat_map do |tanda|
      report(nombre, vuelta, tanda.first.last, grupos.size)
      tanda.map do |grupo, i|
        Thread.new do
          Thread.current[:brief_merger_chat] = chat_with(chat&.api_key)
          merge_call(grupo, origen, "#{nombre}#{vuelta}g#{i}") || { ficha: grupo, origin: origen }
        end
      end.map(&:value)
    end
    { ficha: as_lists(resultados.pluck(:ficha)), origin: resultados.pluck(:origin).reduce({}, :merge) }
  end

  # Tandas de puntos que quepan en una llamada, respetando la categoría de cada uno.
  def split(ficha)
    grupos = [{}]
    tamano = 0
    ficha.each do |campo, puntos|
      Array.wrap(puntos).each do |punto|
        largo = punto.to_json.length
        if tamano.positive? && tamano + largo > MAX_INPUT_CHARS
          grupos << {}
          tamano = 0
        end
        (grupos.last[campo] ||= []) << punto
        tamano += largo
      end
    end
    grupos
  end

  # ── una llamada ─────────────────────────────────────────────────────────────
  def merge_call(entrada, origen, etiqueta, tighten: false)
    raw = ask(entrada, tighten)
    return nil if raw.nil?

    conocidos = origen.keys.to_set
    ficha = Ficha.clean(raw.slice(*entrada.keys)) { |ids| Array(ids).map(&:to_s).select { |id| conocidos.include?(id) } }
    restore_lost(ficha, entrada)
    relabel(ficha.compact_blank, origen, etiqueta)
  end

  def ask(entrada, tighten)
    chat = Thread.current[:brief_merger_chat] || chat_with(nil)
    mensajes = [{ role: 'system', content: PROMPT },
                { role: 'user', content: [(TIGHTEN if tighten), entrada.to_json].compact.join("\n\n") }]
    ATTEMPTS.times do
      raw = chat.call(mensajes, max_tokens: MAX_OUTPUT_TOKENS)
      @lock.synchronize do
        @calls += 1
        chat.last_usage&.each { |k, v| @usage[k] += v.to_i if @usage.key?(k) }
      end
      next if raw.nil?

      @lock.synchronize { @answered += 1 }
      return raw
    end
    nil
  end

  # Identidad, objetivo y modo son uno solo, aunque una tanda sin juntar los deje en lista.
  def singles(ficha)
    Ficha::SINGLE.each { |campo| ficha[campo] = ficha[campo].first if ficha[campo].is_a?(Array) }
    ficha.compact
  end

  # Un OpenaiChat por hilo: guarda los tokens de SU última llamada. La clave llega ya
  # leída para que el hilo no consulte la base.
  def chat_with(api_key)
    ContactTrackings::Assistant::OpenaiChat.new(account: @account, api_key: api_key)
  end

  # ── puntos e ids ────────────────────────────────────────────────────────────
  # Todas las fichas en una, con los puntos de cada categoría uno tras otro.
  # Identidad/objetivo/modo van como lista: cada parte pudo decir algo distinto.
  def combined(partes)
    origen = partes.each_with_object({}) { |f, h| h.merge!(f[:origin]) }
    [as_lists(partes.pluck(:ficha)), origen]
  end

  def as_lists(fichas)
    Ficha::CATEGORIES.index_with { |campo| fichas.flat_map { |f| Array.wrap(f[campo]) } }.compact_blank
  end

  def restore_lost(ficha, entrada)
    GUARDED.each do |campo|
      next if entrada[campo].blank?

      usados = Array(ficha[campo]).flat_map { |p| p['ids'] }.to_set
      perdidos = Array.wrap(entrada[campo]).reject { |p| p['ids'].any? { |id| usados.include?(id) } }
      ficha[campo] = Array(ficha[campo]) + perdidos
    end
  end

  # Ids nuevos para la vuelta siguiente, con el origen de todo lo que juntan.
  def relabel(ficha, origen, etiqueta)
    nuevo = {}
    Ficha.points(ficha).each_with_index do |(_campo, punto), n|
      id = "#{etiqueta}.#{n}"
      nuevo[id] = punto['ids'].flat_map { |viejo| origen.fetch(viejo, []) }.uniq.sort
      punto['ids'] = [id]
    end
    { ficha: ficha, origin: nuevo }
  end

  def with_origin(final)
    ficha = final[:ficha].deep_dup
    Ficha.points(ficha).each do |(_campo, punto)|
      punto['origen'] = punto.delete('ids').flat_map { |id| final[:origin].fetch(id, []) }.uniq.sort
    end
    ficha
  end

  def report(familia, vuelta, hechos, total)
    @progress&.call(:merging_brief, family: familia, round: vuelta, done: hechos, total: total)
  end

  def failure
    { error: :unavailable, usage: @usage, calls: @calls }
  end
end
