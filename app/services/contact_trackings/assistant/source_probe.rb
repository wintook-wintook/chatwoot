# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando §15 — PROBAR LAS FUENTES DEL AGENTE (P1: parecido)
# ================================================================================
# La pestaña «Probar fuentes» del espacio del agente. A diferencia de «Prueba de
# búsqueda» de Base de Conocimiento (todas las fuentes, umbral a mano), aquí cada
# directiva del Entrenamiento se busca COMO LA BUSCA EL AGENTE:
#
#   @buscar_predefinidas(PATITAS)  solo ese grupo · umbral 0.45 (grupo) · toma 3
#   {{doc:Precios}}                solo ese documento · umbral de la cuenta · toma 3
#
# El alcance por grupo y su umbral son los del motor (KnowledgeBaseResponseService
# .grouped_items / .group_threshold); el umbral y el tope, los de la cuenta
# (kbase_setting). Se trae más de lo que el agente toma para que se vea qué quedó
# fuera y por qué: bajo el umbral o fuera del tope.
#
# P1 prueba lo que se busca por parecido. Hojas exactas, ERP y fuentes en vivo se
# listan con `kind` y se prueban en P2/P3.
# ================================================================================

class ContactTrackings::Assistant::SourceProbe
  Directives = KnowledgeBase::Directives
  Engine = KnowledgeBaseResponseService
  # Menos que esto, probablemente no es lo que preguntaron (medido en FR, 03/11/2026).
  STRONG_SIMILARITY = ContactTrackings::Assistant::AssistantTools::STRONG_SIMILARITY
  SHOWN = 8
  MAX_EXCERPT = 300
  ROUTE_RE = /\A\s*@ruta\(\s*([^\s#:)]+)/i
  SIMILARITY = %i[canned_response article google_doc google_sheet].freeze
  KINDS = { sheet_lookup: 'sheet_lookup', erp_query: 'erp', knowledge_source: 'live',
            discourse_integration: 'live', contpaq_support: 'live' }.freeze
  NATIVE = { canned_response: 'canned_response', article: 'article' }.freeze

  def initialize(account, text: nil, api_key: nil)
    @account = account
    @text = text.to_s
    @api_key = api_key
  end

  # Lo que se puede probar: las directivas del Entrenamiento con las rutas que las usan;
  # sin ninguna, las fuentes de la cuenta (`from_account: true`).
  # [{ directive:, mode:, source_name:, group:, kind:, routes:, ready: }]
  def directives
    encontradas = scan
    encontradas.any? ? encontradas : account_sources
  end

  # { kind:, threshold:, threshold_from:, max_results:, results:, used: } o { error: }
  def run(directive, phrase)
    frase = phrase.to_s.strip
    return { error: 'no_phrase' } if frase.blank?

    detectada = detect(directive)
    return { error: 'unknown_directive' } if detectada.nil?

    kind = kind_of(detectada)
    return { kind: kind, pending: true } unless kind == 'similarity'

    similarity(detectada, frase)
  end

  private

  # ── qué directivas tiene el Entrenamiento ────────────────────────────────────
  def scan
    vistas = {}
    @text.split("\n").each do |linea|
      ruta = linea[ROUTE_RE, 1]
      raw_directives(linea).each do |raw|
        item = (vistas[raw.downcase] ||= describe(raw))
        item[:routes] << ruta if item && ruta && item[:routes].exclude?(ruta)
      end
    end
    vistas.values.compact
  end

  def raw_directives(linea)
    regexes = [Directives::CANNED_RE, *Directives::SEARCH_DIRECTIVES.map(&:first)]
    crudas = regexes.flat_map { |re| linea.to_enum(:scan, re).map { Regexp.last_match(0) } }
    crudas + ExternalDb::ConsultaDirectiveRenderer.parse(linea).map(&:raw)
  end

  def describe(raw)
    detectada = detect(raw)
    return nil if detectada.nil?

    kind = kind_of(detectada)
    { directive: raw.strip, kind: kind, routes: [], ready: ready?(detectada), items: (items_count(detectada) if kind == 'similarity') }
      .merge(detectada.slice(:mode, :source_name, :group)).compact
  end

  def detect(raw)
    texto = raw.to_s.strip
    return { mode: :erp_query } if ExternalDb::ConsultaDirectiveRenderer.contains?(texto)

    Directives.detect_search(texto)
  end

  def kind_of(detectada)
    modo = detectada[:mode]
    return 'sheet_data' if modo == :google_sheet && sheet_source(detectada[:source_name])&.config.to_h['sheet_mode'] == 'data'
    return 'similarity' if SIMILARITY.include?(modo)

    KINDS.fetch(modo, 'other')
  end

  def ready?(detectada)
    return @account.external_db_connections.active.exists? if detectada[:mode] == :erp_query

    Directives.ready?(detectada, account: @account, inbox_id: nil)
  end

  # Sin directivas en el texto: lo que la cuenta tiene para buscar por parecido.
  def account_sources
    fuentes = [('@buscar_predefinidas' if Directives.items?(@account, 'canned_response')),
               ('@buscar_articulo' if Directives.items?(@account, 'article')),
               *@account.knowledge_sources.active.where(source_type: %w[google_doc google_sheet]).order(:name).map do |s|
                 s.source_type == 'google_doc' ? "{{doc:#{s.name}}}" : "{{hoja:#{s.name}}}"
               end].compact
    fuentes.filter_map { |raw| describe(raw)&.merge(from_account: true) }
  end

  # ── la búsqueda por parecido, como el motor ──────────────────────────────────
  def similarity(detectada, frase)
    scope = scope_for(detectada)
    return { kind: 'similarity', error: scope } if scope.is_a?(String)
    # Medido el 04/11/2026: un agente real buscaba en dos grupos de predefinidas que no
    # tienen ninguna respuesta. No es «no encontró»: nunca va a encontrar.
    return { kind: 'similarity', error: 'empty_source' } unless scope.exists?

    embedding = embed(frase)
    return { kind: 'similarity', error: 'no_embedding' } if embedding.blank?

    umbral, de_donde = threshold(detectada)
    tope = Engine.kbase_setting(@account, 'max_results').to_i
    items = scope.search_by_embedding(embedding, limit: [SHOWN, tope].max, threshold: 0).to_a
    results(items, umbral, tope).then do |lista|
      { kind: 'similarity', threshold: umbral, threshold_from: de_donde, max_results: tope,
        results: lista, used: lista.count { |r| r[:used] } }
    end
  end

  # Cuántas piezas hay donde busca (nil si el agente no buscaría ahí).
  def items_count(detectada)
    scope = scope_for(detectada)
    scope.is_a?(String) ? nil : scope.count
  end

  # Un String es el motivo por el que el agente no buscaría.
  def scope_for(detectada)
    modo = detectada[:mode]
    return Engine.grouped_items(@account, NATIVE[modo], detectada[:group]) if NATIVE.key?(modo)
    return 'google_disabled' unless @account.feature_enabled?('google_calendar')

    fuente = modo == :google_doc ? doc_source(detectada[:source_name]) : sheet_source(detectada[:source_name])
    fuente ? @account.knowledge_items.where(knowledge_source_id: fuente.id) : 'source_missing'
  end

  def threshold(detectada)
    grupo = Engine.group_threshold(detectada[:group]) if detectada[:mode] == :canned_response
    grupo ? [grupo, 'group'] : [Engine.kbase_setting(@account, 'similarity_threshold'), 'account']
  end

  # El agente toma, en orden, las que pasan el umbral, hasta el tope.
  def results(items, umbral, tope)
    tomadas = 0
    items.map do |item|
      parecido = (1 - item.neighbor_distance).round(3)
      motivo = if parecido < umbral then 'below_threshold'
               elsif tomadas >= tope then 'over_limit'
               end
      tomadas += 1 if motivo.nil?
      { title: item.title.to_s, excerpt: item.content.to_s.squish.truncate(MAX_EXCERPT), similarity: parecido,
        used: motivo.nil?, reason: motivo, weak: parecido < STRONG_SIMILARITY }.compact
    end
  end

  def doc_source(nombre) = named_source('google_doc', nombre)

  def sheet_source(nombre) = named_source('google_sheet', nombre)

  def named_source(tipo, nombre)
    @account.knowledge_sources.active.where(source_type: tipo).find_by('LOWER(name) = LOWER(?)', nombre.to_s.strip)
  end

  def embed(texto) = ContactTrackings::Assistant::Embedding.call(texto, @api_key)
end
