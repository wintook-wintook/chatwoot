# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — FR: LAS HERRAMIENTAS DEL CHAT DE CREACIÓN
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §12. Lo que el modelo puede
# CONSULTAR y PROBAR antes de contestar, para proponer rutas con lo que la cuenta tiene
# de verdad. D7 (03/11/2026): se traen SOLO las herramientas de la rama
# diag/asistente_agentes_ia (P8; ahí las usaba el chat de edición), sin su reporte de
# consumo ni su revisión de encargo, y se agregan dos:
#
#   ver_recursos    lo que tiene la cuenta, con la ficha corta de cada fuente
#   ver_fuente      la ficha completa de una fuente (columnas y filas de una hoja,
#                   títulos de un documento, grupos de predefinidas, campos de un caso)
#   probar_fuente   la BÚSQUEDA REAL de una fuente con una frase de cliente: qué
#                   encontraría y si pasa el umbral de la cuenta
#   ver_directiva   cómo se escribe una directiva del motor (manual §4)
#   probar_ruta     frases al clasificador REAL del motor (dos veces; tres si no coinciden)
#   comprobar       el comprobador sobre el boceto de rutas
#
# TODAS SON DE SOLO LEER O PROBAR: ninguna guarda nada. Cada resultado es CORTO: vuelve
# al contexto del modelo en cada llamada siguiente.
# ================================================================================

class ContactTrackings::Assistant::AssistantTools
  MAX_PHRASES = 6
  MAX_FINDINGS = 8
  MAX_HITS = 3
  MAX_EXCERPT = 240
  # Medido el 03/11/2026 en la cuenta 2: con el umbral de la cuenta (0.20), «¿cuánto cuesta
  # una sesión de terapia?» trae «PATITAS PRECIO CONSULTA GENERAL» (una veterinaria) con
  # 0.43 y «pasa». Lo que de verdad contesta la frase anda arriba de ~0.55.
  STRONG_SIMILARITY = 0.55
  HITS_NOTE = 'pasa_umbral = el agente lo usaría para contestar. parecido_bajo = probablemente NO es lo que pregunta. ' \
              'Revisa el extracto: si no contesta la frase o es de otro negocio, esa fuente daría una respuesta equivocada.'
  MANUAL_PATH = Rails.root.join('docs/motor_agentes_ia_manual.md')
  EMBED_MODEL = 'text-embedding-3-small'
  # Las fuentes que se buscan aquí mismo (knowledge_items con embedding). El foro y
  # CONTPAQi se consultan en vivo fuera del sistema: no se pueden probar desde aquí.
  LOCAL_TYPES = %w[google_sheet google_doc article canned_response].freeze

  RUTAS = { type: 'string',
            description: 'TODAS las líneas @ruta(…) del boceto, una por renglón, y la @ruta_por_defecto. El clasificador ' \
                         'elige entre las rutas que le mandas: una prueba con algunas no vale para el agente completo.' }.freeze

  DEFINITIONS = [
    { name: 'ver_recursos',
      description: 'Lo que tiene ESTA cuenta: cada fuente con lo que tiene dentro (resumen), tipos de caso con sus campos, ' \
                   'etiquetas, acciones disponibles y lo que NO tiene configurado.',
      parameters: { type: 'object', properties: {}, required: [] } },
    { name: 'ver_fuente',
      description: 'La ficha completa de una fuente: qué tiene (columnas y filas de ejemplo de una hoja, partes de un documento, ' \
                   'grupos de predefinidas, títulos de artículos, campos de un tipo de caso), qué se le puede preguntar y cómo ' \
                   'se escribe en una ruta. Úsala antes de proponer una ruta con esa fuente.',
      parameters: { type: 'object', properties: { nombre: { type: 'string' } }, required: ['nombre'] } },
    { name: 'probar_fuente',
      description: 'Busca en una fuente de la cuenta con una frase como la escribiría un cliente, con la MISMA búsqueda que usa ' \
                   'el agente: qué encontró y si pasa el umbral. Úsala para saber si la fuente sirve antes de proponerla.',
      parameters: { type: 'object', properties: { nombre: { type: 'string' }, frase: { type: 'string' } },
                    required: %w[nombre frase] } },
    { name: 'ver_directiva',
      description: 'Cómo se escribe una directiva del motor, qué hace, qué requiere y cómo falla. ' \
                   'Ej.: "hoja_buscar", "crear_ticket", "agendar_calendar", "buscar_predefinidas".',
      parameters: { type: 'object', properties: { nombre: { type: 'string' } }, required: ['nombre'] } },
    { name: 'probar_ruta',
      description: 'Manda frases de cliente al clasificador REAL del motor y dice a qué ruta cae cada una y si es estable. ' \
                   'Úsalo antes de decir que una ruta funciona, con frases de esa ruta y de las que podrían cruzarse.',
      parameters: { type: 'object',
                    properties: { frases: { type: 'array', items: { type: 'string' }, description: "Hasta #{MAX_PHRASES}." },
                                  rutas: RUTAS },
                    required: %w[frases rutas] } },
    { name: 'comprobar',
      description: 'Pasa el boceto de rutas por el comprobador del motor: lo que impide que se ejecute y lo que lo degrada.',
      parameters: { type: 'object', properties: { rutas: RUTAS }, required: ['rutas'] } }
  ].freeze
  NAMES = DEFINITIONS.pluck(:name).freeze

  def self.definitions = DEFINITIONS.map { |d| { type: 'function', function: d } }

  # FD: lo que se probó con probar_ruta en este turno ([{ frase, cae_en, estable, veces }]).
  # Son las pruebas de la conversación: el diagrama las ilumina y al guardar el agente
  # pasan a su pila.
  attr_reader :tested

  # draft: el boceto de rutas que se lleva (puede estar vacío al empezar).
  def initialize(account, draft: '', inbox: nil, api_key: nil)
    @account = account
    @draft = draft.to_s
    @inbox = inbox
    @api_key = api_key
    @tested = []
  end

  # El resultado, en JSON, para el mensaje `tool` del modelo. Nunca levanta: un error
  # vuelve como dato y el modelo sigue.
  def run(name, arguments)
    return { error: "no existe la herramienta #{name}" }.to_json unless NAMES.include?(name)

    send("tool_#{name}", JSON.parse(arguments.presence || '{}')).to_json
  rescue StandardError => e
    Rails.logger.warn "[Asistente/herramientas] #{name}: #{e.message}"
    { error: e.message.truncate(200) }.to_json
  end

  # Para la guardia de DraftingToolLoop: lo que impediría que el motor ejecute el boceto
  # (vacío si está bien o si no hay boceto).
  def route_errors(rutas)
    return [] if rutas.blank?

    findings(ContactTrackings::Assistant::ValidatorService.new(rutas.to_s, account: @account).call[:blocking])
  end

  private

  # ── ver_recursos ────────────────────────────────────────────────────────────
  def tool_ver_recursos(_args)
    {
      fuentes: profiles.call.map { |f| f.slice(:tipo, :nombre, :que_tiene, :como_se_usa) },
      no_tiene: profiles.missing,
      etiquetas: inventory[:labels],
      acciones: Array(inventory[:actions]).select { |a| a[:available] }.pluck(:directive)
    }
  end

  # ── ver_fuente ──────────────────────────────────────────────────────────────
  def tool_ver_fuente(args)
    ficha = profiles.find(args['nombre'])
    return { error: "no hay una fuente «#{args['nombre']}»", fuentes: profiles.call.pluck(:nombre) } if ficha.nil?

    ficha
  end

  # ── probar_fuente ───────────────────────────────────────────────────────────
  def tool_probar_fuente(args)
    frase = args['frase'].to_s.strip
    return { error: 'falta la frase' } if frase.blank?

    fuente = source_named(args['nombre'])
    return { error: "no hay una fuente «#{args['nombre']}»", fuentes: profiles.call.pluck(:nombre) } if fuente.nil?
    return { fuente: fuente.name, en_vivo: true, nota: 'se consulta en vivo fuera del sistema: no se puede probar aquí' } unless
      LOCAL_TYPES.include?(fuente.source_type)

    hits(fuente, frase)
  end

  def hits(fuente, frase)
    embedding = embed(frase)
    return { error: 'no se pudo calcular la búsqueda (sin clave de OpenAI o falló la llamada)' } if embedding.blank?

    umbral = KnowledgeBaseResponseService.kbase_setting(@account, 'similarity_threshold').to_f
    encontrados = scope_for(fuente).search_by_embedding(embedding, limit: MAX_HITS, threshold: 0).to_a
    { fuente: fuente.name, frase: frase, umbral: umbral, nota: HITS_NOTE,
      encontrado: encontrados.map do |item|
        parecido = (1 - item.neighbor_distance).round(2)
        { titulo: item.title.to_s.truncate(80), extracto: item.content.to_s.squish.truncate(MAX_EXCERPT),
          parecido: parecido, pasa_umbral: parecido >= umbral, parecido_bajo: parecido < STRONG_SIMILARITY }
      end }
  end

  # Las nativas (predefinidas, artículos) se buscan por tipo, como el motor.
  def scope_for(fuente)
    items = @account.knowledge_items
    return items.where(source_type: fuente.source_type) if %w[canned_response article].include?(fuente.source_type)

    items.where(knowledge_source_id: fuente.id)
  end

  def source_named(nombre)
    clave = I18n.transliterate(nombre.to_s).downcase.strip
    activas = @account.knowledge_sources.active.to_a
    alias_tipo = { 'predefinidas' => 'canned_response', 'articulos' => 'article', 'centro de ayuda' => 'article' }[clave]
    return activas.find { |s| s.source_type == alias_tipo } if alias_tipo

    activas.find { |s| I18n.transliterate(s.name).downcase.strip == clave } ||
      activas.find { |s| I18n.transliterate(s.name).downcase.include?(clave) }
  end

  def embed(texto)
    return nil if @api_key.blank?

    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    request = Net::HTTP::Post.new(uri, 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => 'application/json')
    request.body = { model: EMBED_MODEL, input: texto }.to_json
    response = http.request(request)
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body).dig('data', 0, 'embedding') : nil
  end

  # ── ver_directiva ───────────────────────────────────────────────────────────
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

  # ── probar_ruta ─────────────────────────────────────────────────────────────
  def tool_probar_ruta(args)
    frases = Array(args['frases']).map { |f| f.to_s.strip }.compact_blank.first(MAX_PHRASES)
    return { error: 'faltan las frases' } if frases.empty?

    texto = with_routes(args['rutas'])
    return { error: 'el boceto no tiene ninguna línea @ruta(…)' } if ContactTrackings::RouteMap.parse(texto).routes.empty?

    clasificador = ContactTrackings::Assistant::DraftClassifier.new(@account, draft: texto, inbox: @inbox)
    frases.map { |f| verdict(clasificador, f) }.tap { |veredictos| @tested.concat(veredictos) }
  end

  # El clasificador no siempre da la misma ruta para la misma frase (medido el 13/10/2026,
  # P8): dos veces y, si no coinciden, una tercera para ver hacia dónde se inclina.
  def verdict(clasificador, frase)
    caidas = Array.new(2) { route_name(clasificador, frase) }
    caidas << route_name(clasificador, frase) if caidas.uniq.size > 1
    principal, veces = caidas.tally.max_by { |_, n| n }
    otras = caidas.uniq - [principal]
    { frase: frase, cae_en: principal, veces: "#{veces}/#{caidas.size}", estable: otras.empty? }
      .merge(otras.any? ? { a_veces_en: otras } : {})
  end

  def route_name(clasificador, frase)
    clasificador.classify(frase)&.name || '(ninguna: falló la clasificación o no hay rutas)'
  end

  # ── comprobar ───────────────────────────────────────────────────────────────
  def tool_comprobar(args)
    v = ContactTrackings::Assistant::ValidatorService.new(with_routes(args['rutas']), account: @account).call
    { bloqueantes: findings(v[:blocking]), degradan: findings(v[:degrading]), ejecuta: v[:blocking].empty? }
  end

  def findings(lista)
    Array(lista).first(MAX_FINDINGS).map { |f| f[:message].to_s.truncate(300) }
  end

  # Las rutas que manda el modelo; si no manda, el boceto que ya se llevaba.
  def with_routes(rutas) = rutas.presence || @draft

  # ── la cuenta ───────────────────────────────────────────────────────────────
  def inventory
    @inventory ||= ContactTrackings::Assistant::InventoryService.new(@account, inbox: @inbox).call
  end

  def profiles
    @profiles ||= ContactTrackings::Assistant::SourceProfiles.new(@account, inbox: @inbox)
  end
end
