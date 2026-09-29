# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LEER UN ENCARGO ENTERO (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
#   trocear (BriefChunker) → entender cada trozo (BriefReader, PARALLEL a la vez)
#     → juntar (BriefMerger) → contradicciones (BriefContradictions)
#     → lo que falta (BriefGaps) → guardar en el encargo
#
# NO SE PAGA DOS VECES UN TROZO: cada trozo guarda su huella y su lectura. Antes de
# llamar a la IA se busca esa huella en el propio encargo (un reintento después de una
# falla relee solo lo que faltó) y en los otros encargos leídos de la cuenta (regenerar
# con un archivo que cambió en un tema relee solo ese tema). Solo si la lectura se hizo
# con las instrucciones actuales del lector (BriefReader::VERSION).
#
# Todo con gpt-4o (decisión A, 23/09): el piso de EngineConfig para :authoring_assistant.
# ================================================================================

class ContactTrackings::Assistant::BriefDigestService
  Chunker = ContactTrackings::Assistant::BriefChunker
  BriefReader = ContactTrackings::Assistant::BriefReader
  Ficha = ContactTrackings::Assistant::BriefFicha

  PARALLEL = 4
  # Encargos de la cuenta donde se buscan trozos ya leídos.
  CACHE_BRIEFS = 20
  # Precio de lista de gpt-4o, USD por millón de tokens (entrada, salida). Solo para
  # informar lo que costó; no decide nada.
  PRICE_PER_MILLION = { 'prompt_tokens' => 2.5, 'completion_tokens' => 10.0 }.freeze

  def initialize(brief, progress: nil)
    @brief = brief
    @account = brief.account
    @progress = progress
  end

  def call
    inicio = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @brief.update!(status: 'reading')
    # M1 y M4: qué parte del encargo necesita IA (ver BriefReadingPlan).
    @plan = ContactTrackings::Assistant::BriefReadingPlan.new(@account, content: @brief.content)
    trozos = @plan.chunks
    lecturas = read_all(trozos)
    return fail!(@error || :reading, trozos, lecturas) if lecturas.any?(&:nil?)

    juntado = merge(lecturas)
    return fail!(:merging, trozos, lecturas) if juntado[:error]

    finish(trozos, lecturas, juntado, inicio)
  end

  private

  # ── leer ────────────────────────────────────────────────────────────────────
  # [{ ficha:, origin:, usage:, cached: }] en el orden de los trozos; nil si falló.
  def read_all(trozos)
    guardadas = cached_readings
    lecturas = trozos.map { |t| t.text.strip.empty? ? blank_reading(t) : from_cache(guardadas[t.sha256], t) }
    pendientes = trozos.reject { |t| lecturas[t.index] }
    report(:reading_brief, trozos.size - pendientes.size, trozos.size)
    read_pending(pendientes, lecturas, trozos.size)
    lecturas
  end

  def read_pending(pendientes, lecturas, total)
    return if pendientes.empty?

    lectores = pendientes.map do |t|
      ContactTrackings::Assistant::BriefReader.new(@account, chunk: t, filename: @brief.filename, rules_apart: @plan.rules_apart?)
    end
    return @error = :no_api_key if lectores.first.api_key.blank?

    lectores.each(&:api_key) # la clave se lee acá: los hilos no tocan la base
    cola = Queue.new
    lectores.each { |l| cola << l }
    candado = Mutex.new
    Array.new([PARALLEL, lectores.size].min) { Thread.new { work(cola, candado, lecturas, total) } }.each(&:join)
  end

  def work(cola, candado, lecturas, total)
    while (lector = pop(cola))
      resultado = lector.call
      candado.synchronize do
        lecturas[lector.chunk.index] = resultado[:error] ? nil : resultado
        report(:reading_brief, lecturas.compact.size, total)
      end
    end
  end

  def pop(cola)
    cola.pop(true)
  rescue ThreadError
    nil
  end

  # sha256 → lectura guardada (la ficha del trozo). Primero las del propio encargo.
  def cached_readings
    otros = TrackingAgentBrief.where(account: @account).where.not(id: @brief.id)
                              .order(updated_at: :desc).limit(CACHE_BRIEFS).pluck(:chunks)
    ([@brief.chunks] + otros).reverse.each_with_object({}) do |trozos, cache|
      Array(trozos).each do |t|
        cache[t['sha256']] = t['lectura'] if t['lectura'].present? && t['lector'].to_s == reader_version
      end
    end
  end

  # Con las reglas leídas aparte, el lector recibe otra instrucción: su lectura no se
  # mezcla con la de antes (ver BriefReader#version).
  def reader_version = BriefReader.version(rules_apart: @plan.rules_apart?)

  def from_cache(guardada, trozo)
    return nil if guardada.nil?

    ficha, origen = Ficha.from_reading(guardada, trozo.index)
    { ficha: ficha, origin: origen, usage: {}, cached: true }
  end

  # Un trozo que quedó en blanco (eran solo reglas numeradas) no se le manda a la IA.
  def blank_reading(trozo)
    ficha, origen = Ficha.from_reading({}, trozo.index)
    { ficha: ficha, origin: origen, usage: {}, cached: true }
  end

  # ── juntar ──────────────────────────────────────────────────────────────────
  def merge(lecturas)
    partes = lecturas.map { |l| l.slice(:ficha, :origin) }
    ContactTrackings::Assistant::BriefMerger.new(@account, partials: partes, progress: @progress).call
  end

  # ── guardar ─────────────────────────────────────────────────────────────────
  def finish(trozos, lecturas, juntado, inicio)
    choques = ContactTrackings::Assistant::BriefContradictions.new(@account, ficha: juntado[:ficha]).call
    # M2: las reglas se ajustan al presupuesto; lo que no entra queda como anexo (D3).
    @presupuesto = ContactTrackings::Assistant::BriefBudget.new(@account, ficha: @plan.with_numbered_rules(choques[:ficha])).call
    # M3: más de 20 temas se agrupan por lo que el cliente viene a pedir.
    @grupos = ContactTrackings::Assistant::BriefTopicGroups.new(@account, ficha: @presupuesto[:ficha]).call
    juntado = juntado.merge(contradictions_usage: choques[:usage])
    @brief.update!(status: 'ready', chunks: stored_chunks(trozos, lecturas), digest: digest_for(@grupos[:ficha]),
                   usage: usage(lecturas, juntado, inicio))
    @brief
  end

  def digest_for(ficha)
    inventario = ContactTrackings::Assistant::InventoryService.new(@account).call
    faltas = ContactTrackings::Assistant::BriefGaps.new(ficha, inventory: inventario).call
    { 'ficha' => ficha, 'faltas' => faltas, 'caracteres' => Ficha.size(ficha), 'anexo' => @presupuesto[:anexo].presence,
      'reglas_caracteres' => @presupuesto.slice(:antes, :despues).stringify_keys,
      'temas_agrupados' => @grupos.slice(:antes, :despues).stringify_keys,
      'fuentes_sugeridas' => @plan.sources.presence&.map { |s| s.except('secciones') },
      'limites' => ContactTrackings::Assistant::EngineLimits.call(ficha).presence }.compact
  end

  # Lo que se guarda por trozo: dónde está, su huella y su lectura (sin el texto, que
  # se rearma del .md con first_line/last_line).
  def stored_chunks(trozos, lecturas)
    trozos.map do |t|
      lectura = lecturas[t.index]
      t.to_h.stringify_keys.merge('lectura' => lectura && strip_ids(lectura[:ficha]),
                                  'lector' => lectura && reader_version)
    end
  end

  def strip_ids(ficha)
    copia = ficha.deep_dup
    Ficha.points(copia).each { |(_campo, punto)| punto.delete('ids') }
    copia
  end

  def usage(lecturas, juntado, inicio)
    partes = token_parts(lecturas, juntado)
    {
      'modelo' => ContactTrackings::EngineConfig.model_for(nil, :authoring_assistant),
      'trozos' => lecturas.size, 'trozos_reusados' => lecturas.count { |l| l[:cached] },
      'juntar' => juntado[:usage].merge('llamadas' => juntado[:calls]), **partes,
      'reglas_numeradas' => @plan.numbered&.rules&.size, 'trozos_en_fuente' => @plan.summarized_count,
      'costo_usd' => cost(sum_tokens([*partes.values, juntado[:usage]])).round(4),
      'segundos' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - inicio).round(1),
      'reused_from' => @brief.usage['reused_from']
    }.compact
  end

  # Los tokens de cada paso con IA, salvo juntar (que trae también sus llamadas).
  def token_parts(lecturas, juntado)
    { 'lectura' => sum_tokens(lecturas.pluck(:usage)), 'contradicciones' => sum_tokens([juntado[:contradictions_usage]]),
      'presupuesto' => sum_tokens([@presupuesto&.dig(:usage), @grupos&.dig(:usage)]) }
  end

  def sum_tokens(lista)
    PRICE_PER_MILLION.keys.index_with { |k| lista.sum { |u| u.to_h[k].to_i } }
  end

  def cost(tokens)
    PRICE_PER_MILLION.sum { |k, precio| tokens[k].to_i * precio / 1_000_000.0 }
  end

  # Lo leído hasta la falla queda guardado: el reintento no lo vuelve a pagar.
  def fail!(etapa, trozos, lecturas)
    @brief.update!(status: 'failed', chunks: stored_chunks(trozos, lecturas),
                   usage: @brief.usage.merge('error' => etapa.to_s))
    @brief
  end

  def report(etapa, hechos, total)
    @progress&.call(etapa, done: hechos, total: total)
  end
end
