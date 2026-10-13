# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS HERRAMIENTAS DEL ASISTENTE (P8, prototipo)
# ================================================================================
# Lo que el modelo puede CONSULTAR y PROBAR antes de contestar, sobre servicios que ya
# existen. Salió de la medición del 12/10/2026 (docs/diagnostico_asistente_agentes_ia_plan.md,
# Paso 0): el Asistente decía «arreglado» sin haberlo probado (T3) y proponía reglas que
# el Entrenamiento ya tenía (T5).
#
# TODAS SON DE SOLO LEER O PROBAR: ninguna guarda nada. `comprobar` y `probar_ruta`
# aplican el cambio sobre una copia en memoria del Entrenamiento que está en pantalla.
#
# EL CAMBIO VIAJA SOLO, NO EL ENTRENAMIENTO: el modelo manda la línea @ruta(…) o la
# [SECCIÓN] que quiere probar y el código la pone en su lugar (DraftPieces.restore).
# Mandar el Entrenamiento entero en cada prueba multiplicaría el costo por cada vuelta.
#
# Cada resultado es CORTO (columnas + 3 filas, no la hoja entera): vuelve al contexto
# del modelo en cada llamada siguiente.
# ================================================================================

class ContactTrackings::Assistant::AssistantTools
  MAX_PHRASES = 6
  MAX_FINDINGS = 8
  SAMPLE_ROWS = 3
  MANUAL_PATH = Rails.root.join('docs/motor_agentes_ia_manual.md')
  # Qué etapa avisa cada herramienta en la pantalla (TurnProgress).
  STAGES = {
    'ver_recursos' => :tool_resources, 'ver_directiva' => :tool_directive, 'ver_hoja' => :tool_sheet,
    'comprobar' => :tool_check, 'probar_ruta' => :tool_route
  }.freeze

  CAMBIO = { type: 'string',
             description: 'Opcional. La pieza cambiada o nueva, COMPLETA: una línea @ruta(…) entera, o una [SECCIÓN] con todo su ' \
                          'texto. Se aplica sobre el Entrenamiento actual, solo para la prueba. Sin esto se prueba el actual.' }.freeze

  DEFINITIONS = [
    { name: 'ver_recursos',
      description: 'Lo que tiene ESTA cuenta: fuentes (con su directiva exacta), hojas con sus columnas, tipos de caso, etiquetas, ' \
                   'grupos de respuestas predefinidas y acciones disponibles.',
      parameters: { type: 'object', properties: {}, required: [] } },
    { name: 'ver_directiva',
      description: 'Cómo se escribe una directiva del motor, qué hace, qué requiere y cómo falla, y si esta cuenta la tiene lista. ' \
                   'Ej.: "hoja", "crear_ticket", "agendar_calendar", "buscar_foro".',
      parameters: { type: 'object', properties: { nombre: { type: 'string' } }, required: ['nombre'] } },
    { name: 'ver_hoja',
      description: 'Columnas y unas filas de ejemplo de una hoja de Google de la cuenta, para escribir frases y reglas con sus valores reales.',
      parameters: { type: 'object', properties: { nombre: { type: 'string' } }, required: ['nombre'] } },
    { name: 'comprobar',
      description: 'Pasa el Entrenamiento (con el cambio, si lo mandas) por el comprobador del motor: ' \
                   'lo que impide que se ejecute y lo que lo degrada.',
      parameters: { type: 'object', properties: { cambio: CAMBIO }, required: [] } },
    { name: 'probar_ruta',
      description: 'Manda frases de cliente al clasificador REAL del motor y dice a qué ruta cae cada una, con el cambio aplicado si lo mandas. ' \
                   'Úsalo antes de decir que una ruta nueva o corregida funciona, con frases de esa ruta y de las que podrían cruzarse.',
      parameters: { type: 'object',
                    properties: { frases: { type: 'array', items: { type: 'string' }, description: "Hasta #{MAX_PHRASES}." },
                                  cambio: CAMBIO },
                    required: ['frases'] } }
  ].freeze

  def self.definitions
    DEFINITIONS.map { |d| { type: 'function', function: d } }
  end

  # usage: el consumo del turno (TokenUsage); cada frase clasificada se cuenta ahí.
  def initialize(account, draft:, inbox: nil, usage: nil)
    @account = account
    @draft = draft.to_s
    @inbox = inbox
    @usage = usage
  end

  # El resultado, en JSON, para el mensaje `tool` del modelo. Nunca levanta: un error
  # vuelve como dato y el modelo sigue.
  def run(name, arguments)
    return { error: "no existe la herramienta #{name}" }.to_json unless STAGES.key?(name)

    send("tool_#{name}", JSON.parse(arguments.presence || '{}')).to_json
  rescue StandardError => e
    Rails.logger.warn "[Asistente/herramientas] #{name}: #{e.message}"
    { error: e.message.truncate(200) }.to_json
  end

  private

  # ── ver_recursos ────────────────────────────────────────────────────────────
  def tool_ver_recursos(_args)
    {
      fuentes: Array(inventory[:sources]).map { |s| { nombre: s[:name], directiva: s[:directive] } },
      hojas: sheets.to_h { |s| [s.name, columns(s)] },
      tipos_de_caso: inventory[:case_types],
      etiquetas: inventory[:labels],
      grupos_predefinidas: Array(inventory[:canned_groups]).pluck(:prefix),
      acciones: Array(inventory[:actions]).select { |a| a[:available] }.pluck(:directive)
    }
  end

  # ── ver_directiva ───────────────────────────────────────────────────────────
  # La ficha del manual del motor (§4) y el estado en la cuenta (EngineCatalog).
  def tool_ver_directiva(args)
    clave = args['nombre'].to_s.delete('@{}').split(/[:(]/).first.to_s.strip.downcase
    return { error: 'falta el nombre' } if clave.blank?

    fichas = ContactTrackings::Assistant::EngineCatalog.new(inventory).call
    ficha = fichas.find { |f| f[:syntax].to_s.downcase.include?(clave) || f[:key] == clave }
    { manual: manual_card(clave), en_esta_cuenta: ficha&.slice(:syntax, :status, :items) }.compact
  end

  def manual_card(clave)
    texto = MANUAL_PATH.read
    inicio = texto.index(/^#### `[^`]*#{Regexp.escape(clave)}[^`]*`.*$/i)
    return nil if inicio.nil?

    fin = texto.index(/^\#{2,4} /, inicio + 5) || texto.size
    texto[inicio...fin].strip.truncate(1500)
  end

  # ── ver_hoja ────────────────────────────────────────────────────────────────
  def tool_ver_hoja(args)
    nombre = args['nombre'].to_s.strip
    hoja = sheets.find { |s| s.name.casecmp?(nombre) }
    return { error: "no hay una hoja «#{nombre}» en la cuenta", hojas: sheets.map(&:name) } if hoja.nil?

    filas = hoja.google_sheet_rows.order(:row_index)
    { nombre: hoja.name, columnas: columns(hoja), filas: filas.count,
      ejemplo: filas.limit(SAMPLE_ROWS).map(&:data) }
  end

  # ── comprobar ───────────────────────────────────────────────────────────────
  def tool_comprobar(args)
    texto = with_change(args['cambio'])
    return texto if texto.is_a?(Hash)

    v = ContactTrackings::Assistant::ValidatorService.new(texto, account: @account).call
    { bloqueantes: findings(v[:blocking]), degradan: findings(v[:degrading]), ejecuta: v[:blocking].empty? }
  end

  def findings(lista)
    Array(lista).first(MAX_FINDINGS).map { |f| f[:message].to_s.truncate(300) }
  end

  # ── probar_ruta ─────────────────────────────────────────────────────────────
  def tool_probar_ruta(args)
    texto = with_change(args['cambio'])
    return texto if texto.is_a?(Hash)

    frases = phrases(args['frases'])
    return { error: 'faltan las frases' } if frases.empty?

    clasificador = ContactTrackings::Assistant::DraftClassifier.new(@account, draft: texto, inbox: @inbox)
    @usage&.add_classifications(frases.size)
    frases.map { |f| { frase: f, cae_en: clasificador.classify(f)&.name || '(ninguna: falló la clasificación o no hay rutas)' } }
  end

  def phrases(lista)
    Array(lista).map { |f| f.to_s.strip }.compact_blank.first(MAX_PHRASES)
  end

  # El Entrenamiento de la pantalla con la pieza cambiada en su lugar (o agregada), o
  # un { error: } si el cambio no trae ninguna pieza reconocible.
  def with_change(cambio)
    return @draft if cambio.blank?

    claves = ContactTrackings::Assistant::DraftPieces.new(cambio).pieces.keys - [ContactTrackings::Assistant::DraftPieces::PREAMBLE_KEY]
    return { error: 'el cambio tiene que ser una línea @ruta(…) completa o una [SECCIÓN] con su texto' } if claves.empty?

    ContactTrackings::Assistant::DraftPieces.restore(theirs: @draft, mine: cambio, keys: claves)
  end

  # ── la cuenta ───────────────────────────────────────────────────────────────
  def inventory
    @inventory ||= ContactTrackings::Assistant::InventoryService.new(@account, inbox: @inbox).call
  end

  # Las mismas que ve el inventario: solo las activas.
  def sheets
    @sheets ||= @account.knowledge_sources.active.where(source_type: 'google_sheet').order(:name).to_a
  end

  def columns(hoja)
    hoja.google_sheet_rows.order(:row_index).first&.data&.keys
  end
end
