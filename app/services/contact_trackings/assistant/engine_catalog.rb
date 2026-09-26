# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE EL MOTOR OFRECE, Y SI LA CUENTA LO TIENE
# ================================================================================
# La pestaña Recursos del Asistente (pedido del usuario, 23/09/2026): una ficha por
# cada cosa que el motor sabe hacer —fuentes, acciones, piezas del Entrenamiento— con
# su estado en ESTA cuenta y los nombres exactos para copiar. Antes la pestaña solo
# mostraba lo que la cuenta tenía conectado: una directiva sin configurar ni aparecía,
# y nadie se enteraba de que existía (ej.: {{consulta:}} con el ERP apagado).
#
# DE DÓNDE SALE LA LISTA (no se escribe a mano):
#   · fuentes de búsqueda: KnowledgeBase::Directives::SEARCH_DIRECTIVES, por su modo;
#     un modo nuevo sin ficha acá hace fallar engine_catalog_spec;
#   · qué tiene la cuenta y con qué nombre: BriefTools (la misma tabla que usan las
#     instrucciones iniciales) sobre el inventario (InventoryService).
# Los TEXTOS (qué hace, cuándo conviene, qué necesita) viven en el i18n de la pantalla:
# TRACKING_ASSISTANT_VIEW.CATALOG_<KEY>_*. Salen de docs/motor_agentes_ia_manual.md §4.
#
# ESTADO de cada ficha:
#   ready    la cuenta la tiene lista; `items` trae cómo escribirla, tal cual
#   missing  la cuenta no la tiene configurada (la ficha dice dónde se configura)
#   depends  no depende de la cuenta sino del canal o del agente
# ================================================================================

class ContactTrackings::Assistant::EngineCatalog
  Card = Struct.new(:key, :group, :syntax, :status, :items, keyword_init: true)

  # modo de KnowledgeBase::Directives::SEARCH_DIRECTIVES → ficha
  SEARCH_MODES = {
    article: 'articulo',
    knowledge_source: 'foro',
    google_doc: 'doc',
    google_sheet: 'hoja',
    discourse_integration: 'discourse',
    contpaq_support: 'contpaq',
    sheet_lookup: 'hoja_buscar'
  }.freeze

  # ficha → [grupo, cómo se escribe, tipo en BriefTools (o nil)]
  CARDS = {
    'erp' => ['sources', '{{consulta:nombre}}', 'erp'],
    'predefinidas' => ['sources', '@buscar_predefinidas(GRUPO)', 'predefinidas'],
    'articulo' => ['sources', '@buscar_articulo', 'articulo'],
    'foro' => ['sources', '@buscar_foro(nombre)', 'foro'],
    'discourse' => ['sources', '@discourse', nil],
    'contpaq' => ['sources', '@soporte_contpaq(nombre)', 'contpaq'],
    'doc' => ['sources', '{{doc:nombre}}', 'documento'],
    'hoja' => ['sources', '{{hoja:nombre}}', 'hoja'],
    'crear_ticket' => ['actions', '@crear_ticket(tipo=…)', 'ticket'],
    'estado_ticket' => ['actions', Cases::TicketStatusService::DIRECTIVE, nil],
    'agendar' => ['actions', '@agendar_calendar', 'agenda'],
    # proyecto@hoja_buscar, pieza 4: depende de que el agente aparte con modo=tentativo.
    'confirmar_servicio' => ['actions', '@confirmar_servicio(requiere=pago)', nil],
    # proyecto@solicitudes (pieza 5): varios servicios en un mensaje, un caso y una agenda por cada uno.
    'solicitudes' => ['actions', '@solicitudes -> @crear_ticket(tipo=…) -> @agendar_calendar(…) -> {{hoja_buscar: …}}', nil],
    # proyecto@hoja_buscar: sus ejemplos salen de las hojas de la cuenta (ver #sheet_lookup_items).
    'hoja_buscar' => ['actions', '{{hoja_buscar: Hoja | columna=? | columna a regresar}}', nil],
    'adjunto' => ['actions', '{{nombre_del_archivo}}', nil],
    'ruta' => ['structure', '@ruta(nombre #etiqueta: frases del cliente): fuente -> acción', nil],
    'ruta_defecto' => ['structure', '@ruta_por_defecto: nombre', nil],
    'etiqueta' => ['structure', '#etiqueta', nil],
    'seccion' => ['structure', '[NOMBRE DE LA SECCIÓN]', nil],
    'contexto' => ['structure', 'Definición → Contexto', nil]
  }.freeze
  GROUPS = %w[sources actions structure].freeze
  # Las que siempre están: son gramática del motor o dependen solo del Entrenamiento.
  ALWAYS_READY = %w[estado_ticket ruta ruta_defecto etiqueta seccion contexto confirmar_servicio solicitudes].freeze
  # Las que dependen del canal (@discourse: hook del inbox) o del agente (archivos).
  DEPENDS = %w[discourse adjunto].freeze
  MAX_ITEMS = 30

  def initialize(inventory)
    @inventory = inventory
  end

  def call
    CARDS.map do |key, (grupo, sintaxis, _)|
      Card.new(key: key, group: grupo, syntax: sintaxis, status: status(key), items: items(key).first(MAX_ITEMS)).to_h
    end
  end

  private

  def status(key)
    return 'ready' if ALWAYS_READY.include?(key)
    return 'depends' if DEPENDS.include?(key)

    items(key).any? ? 'ready' : 'missing'
  end

  def items(key)
    case key
    when 'predefinidas' then canned_items
    when 'etiqueta' then Array(@inventory[:labels]).map { |l| "##{l}" }
    when 'estado_ticket' then [Cases::TicketStatusService::DIRECTIVE]
    when 'hoja_buscar' then sheet_lookup_items
    else tool_directives(key)
    end
  end

  def tool_directives(key)
    tipo = CARDS.dig(key, 2)
    tipo ? Array(ContactTrackings::Assistant::BriefTools.directives(tipo, @inventory)) : []
  end

  # Una por hoja de la cuenta, con las columnas por llenar: cuáles son depende de la hoja.
  def sheet_lookup_items
    tool_directives('hoja').filter_map do |directiva|
      nombre = directiva[/\{\{hoja:([^}]+)\}\}/, 1]
      "{{hoja_buscar: #{nombre} | columna=? | columna a regresar}}" if nombre
    end
  end

  # @buscar_predefinidas sola y una por grupo de la cuenta (prefijo del short_code).
  def canned_items
    return [] if tool_directives('predefinidas').empty? && Array(@inventory[:canned_groups]).empty?

    ['@buscar_predefinidas'] + Array(@inventory[:canned_groups]).map { |g| "@buscar_predefinidas(#{g[:prefix]})" }
  end
end
