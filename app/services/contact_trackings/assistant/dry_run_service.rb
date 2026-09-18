# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — F6: PROBAR SIN ENVIAR NADA
# ================================================================================
# Toma un Entrenamiento (guardado o borrador) y UNA pregunta, y responde qué haría
# el motor con ella: a qué rama cae, qué fuente consultaría, qué fragmentos traería
# esa fuente, con qué etiqueta cerraría y si abriría un caso.
#
# QUÉ PROBLEMA RESUELVE, QUE EL COMPROBADOR NO
#   El comprobador (ValidatorService) responde "¿esto se ejecuta?". Contesta gratis y
#   al instante porque solo parsea. Lo que NO puede contestar es "¿se ejecuta BIEN?":
#   un Entrenamiento con tres ramas impecables puede mandar todas las preguntas de
#   soporte a la rama comercial y parsear perfecto. Eso solo se ve corriéndolo.
#
# NO ENVÍA NADA
#   No crea Message, no toca la conversación, no abre casos y no marca el ticket. La
#   única escritura posible es la que hace OpenAI del otro lado (cobrar los tokens).
#   Por eso se dispara con un botón y nunca sola.
#
# NO REDACTA LA RESPUESTA — decisión deliberada
#   El mock del plan (§7.6) mostraba también la respuesta final. No se hace, y no por
#   falta de tiempo: redactarla de verdad exige el prompt completo del agente, el
#   objetivo, la regla de rama y el HISTORIAL de la conversación, que ensambla
#   KnowledgeBaseResponseService#generate_contextual_reply — 800 líneas atadas a una
#   conversación real que acá no existe.
#
#   Una respuesta armada por un SEGUNDO camino se vería igual de autoritaria y diría
#   otra cosa que el agente en vivo. Este módulo entero existe para que se vea lo que
#   el motor hace de verdad; una respuesta "parecida" sería la mentira más cara de
#   todas. Lo que sí decide si la respuesta puede llegar a ser correcta son los
#   FRAGMENTOS: si vuelven los equivocados, no hay redacción que lo salve. Eso sí se
#   muestra, y con su similitud.
#
# QUÉ SE PUEDE CORRER EN SECO Y QUÉ NO
#   Las fuentes que buscan en pgvector local (respuestas predefinidas, artículos,
#   Google Doc/Hoja en modo FAQ) se corren de verdad. Las que consultan un servicio
#   externo en vivo (foro Discourse, Contpaq, hoja en modo Datos, {{consulta:}} al
#   ERP) no se ejecutan: se dice cuál es y se sigue. El resto del informe —rama,
#   etiqueta, caso— sale igual, que es la parte que el comprobador no podía dar.
#
#   MODE_EXECUTION es la tabla de esa decisión. El spec exige que TODO modo de
#   KnowledgeBase::Directives::SEARCH_DIRECTIVES esté listado: una fuente nueva que
#   nadie clasifique acá rompe el spec en vez de aparecer como "no se puede probar"
#   sin que nadie lo haya decidido.
# ================================================================================

class ContactTrackings::Assistant::DryRunService
  include KnowledgeEmbeddable

  Result = Struct.new(:payload, :error, keyword_init: true) do
    def success?
      error.blank?
    end
  end

  # Cuánto de cada fragmento se muestra. Alcanza para reconocer de qué habla sin
  # convertir el panel en un volcado del corpus.
  EXCERPT_CHARS = 220

  # Cómo se comporta cada modo en seco.
  #   :pgvector → se ejecuta de verdad contra los items locales
  #   :live     → consulta un servicio externo; no se corre
  #   :mixed    → depende de la configuración de la fuente (hoja: FAQ vs Datos)
  MODE_EXECUTION = {
    canned_response: :pgvector,
    article: :pgvector,
    knowledge_source: :live,
    google_doc: :pgvector,
    google_sheet: :mixed,
    discourse_integration: :live,
    contpaq_support: :live,
    erp_query: :live
  }.freeze

  def initialize(account, draft:, question:, inbox: nil)
    @account  = account
    @draft    = draft.to_s
    @question = question.to_s.strip
    @inbox    = inbox
  end

  def call
    return Result.new(error: :blank_question) if @question.blank?
    return Result.new(error: :blank_draft)    if @draft.blank?

    map = ContactTrackings::RouteMap.parse(@draft)
    route = pick_route(map)

    Result.new(payload: {
                 question: @question,
                 model: router_model,
                 routes: route_summary(map, route),
                 source: source_report(map, route),
                 tag: route&.hashtag,
                 case: ContactTrackings::Assistant::CaseForecast
                         .new(@account, draft: @draft, map: map, route: route).call
               })
  end

  private

  # ------------------------------------------------------------------
  # Rama
  # ------------------------------------------------------------------

  # Se llama al clasificador REAL. Con una sola rama declarada ni pregunta al
  # modelo (devuelve esa) — mismo atajo que en producción, así que la prueba en
  # seco tampoco gasta tokens ahí.
  #
  # ⚠ En TODO este archivo la pregunta "¿hay ramas?" se hace con
  # `map.routes.empty?` y nunca con `map.blank?`. RouteMap define `present?` pero
  # no `empty?`, así que Object#blank? cae en `!self` y devuelve SIEMPRE false: un
  # mapa vacío responde a la vez "no present" y "no blank". Escrito con `blank?`,
  # esta guarda no se disparaba nunca y un Entrenamiento sin ramas salía reportado
  # como si tuviera una.
  def pick_route(map)
    return nil if map.routes.empty?

    ContactTrackings::BranchClassifierService.new(tracking_double, message_double, map).classify
  rescue StandardError => e
    Rails.logger.warn "[Asistente/EnSeco] no se pudo clasificar: #{e.message}"
    nil
  end

  # NO se informa "la eligió el clasificador" vs "cayó en la por defecto": el
  # clasificador devuelve una Route y no dice por cuál de los dos caminos llegó.
  # Deducirlo sería adivinar. Se informa el dato verificable —cuál salió, cuál es
  # la por defecto— y la pantalla avisa cuando coinciden, que es el caso en el que
  # un fallo de clasificación pasaría desapercibido.
  def route_summary(map, route)
    {
      declared: map.names,
      chosen: route&.name,
      description: route&.description,
      default: map.default&.name,
      single: map.routes.one?,
      # Sin ramas el motor no rutea: lee la directiva suelta del prompt, si la hay.
      none_declared: map.routes.empty?
    }
  end

  # ------------------------------------------------------------------
  # Fuente
  # ------------------------------------------------------------------

  # Sin ramas, la fuente es la del prompt entero (precedencia del catálogo). Con
  # ramas, la de la rama elegida y solo esa — igual que
  # KnowledgeBaseResponseService#detect_directive.
  def source_report(map, route)
    directive_text = map.routes.empty? ? @draft : route&.directive
    return { directive: nil, reason: :no_source } if directive_text.blank?

    directive = KnowledgeBase::Directives.detect(directive_text)
    return { directive: directive_text.strip, reason: :unreadable } if directive.blank?

    base = {
      directive: directive_text.strip,
      mode: directive[:mode],
      source_name: directive[:source_name],
      group: directive[:group],
      available: KnowledgeBase::Directives.ready?(directive, account: @account, inbox_id: @inbox&.id)
    }
    return base.merge(reason: :source_missing) unless base[:available]

    base.merge(execute(directive))
  end

  def execute(directive)
    case MODE_EXECUTION[directive[:mode]]
    when :pgvector then search(directive)
    when :live     then { reason: :live_source }
    when :mixed    then execute_mixed(directive)
    else { reason: :unsupported_mode }
    end
  end

  # La hoja de cálculo tiene dos modos y solo uno es buscable: en modo Datos el
  # resultado lo calcula SheetQueryService sobre la hoja viva, no hay fragmentos.
  def execute_mixed(directive)
    source = named_source('google_sheet', directive[:source_name])
    return { reason: :source_missing } if source.nil?
    return { reason: :live_source, sheet_mode: 'data' } if source.config['sheet_mode'] == 'data'

    search(directive)
  end

  # La búsqueda de verdad: mismo embedding, mismo alcance, mismo umbral y mismo
  # tope que usa el motor.
  def search(directive)
    scope, threshold = scope_for(directive)
    return { reason: :source_missing } if scope.nil?

    embedding = embed(@question)
    return { reason: :embedding_failed } if embedding.blank?

    items = scope.search_by_embedding(embedding, limit: setting('max_results'), threshold: threshold)
    {
      threshold: threshold,
      items: items.map { |i| item_json(i) },
      reason: (:no_match if items.empty?)
    }.compact
  end

  # Espejo del `case` de KnowledgeBaseResponseService#perform. Cada rama apunta al
  # método que la implementa allá, para que se puedan comparar de un vistazo.
  def scope_for(directive)
    case directive[:mode]
    when :canned_response # perform_pgvector(question, 'canned_response', group)
      [KnowledgeBase::CannedGroup.scope(@account, 'canned_response', directive[:group]),
       KnowledgeBase::CannedGroup.threshold(directive[:group]) || setting('similarity_threshold')]
    when :article # perform_pgvector(question, 'article')
      [@account.knowledge_items.where(source_type: 'article'), setting('similarity_threshold')]
    when :google_doc, :google_sheet # perform_google_doc / perform_sheet_faq
      source = named_source(directive[:mode].to_s, directive[:source_name])
      source && [@account.knowledge_items.where(knowledge_source_id: source.id), setting('similarity_threshold')]
    end
  end

  def named_source(source_type, name)
    return nil if name.blank?

    @account.knowledge_sources.active
            .where(source_type: source_type)
            .where('LOWER(name) = LOWER(?)', name).first
  end

  def item_json(item)
    {
      title: item.title,
      excerpt: item.content.to_s.squish.truncate(EXCERPT_CHARS),
      similarity: (1 - item.neighbor_distance).round(4)
    }
  end

  # ------------------------------------------------------------------
  # Piezas prestadas
  # ------------------------------------------------------------------

  # El clasificador y TicketCreatorService.fallback? esperan un ContactTracking y un
  # Message. Acá no hay ninguno de los dos: el borrador no está guardado y no existe
  # conversación. Se arman objetos REALES sin persistir (`new`, jamás `save`) en vez
  # de dobles a medida: si mañana el clasificador leyera otro atributo del mensaje,
  # con un Struct explotaría y con esto sigue existiendo.
  def message_double
    @message_double ||= Message.new(account: @account, content: @question, message_type: :incoming)
  end

  def tracking_double
    @tracking_double ||= ContactTracking.new(inbox: @inbox, complementary_prompt: @draft)
  end

  def router_model
    ContactTrackings::EngineConfig.model_for_tracking(tracking_double, :router)
  end

  def setting(key)
    KnowledgeBaseResponseService.kbase_setting(@account, key)
  end

  # Mismo modelo de embedding y misma key por cuenta que usan los jobs de sync y el
  # motor: si la pregunta se vectorizara distinto, las similitudes del panel no
  # serían comparables con las de producción.
  def embed(text)
    generate_embedding(@account, text)
  end
end
