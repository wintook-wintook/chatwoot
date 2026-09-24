# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL COMPROBADOR
# ================================================================================
# Servicio: ContactTrackings::Assistant::ValidatorService
# Descripción: Dado un Entrenamiento escrito, dice —SIN IA— qué va a leer el motor
#              de él y qué no va a ejecutar.
#
# EL PROBLEMA QUE RESUELVE:
#   El motor es fail-soft de punta a punta: una directiva mal escrita no produce un
#   error, deja de existir. Un Entrenamiento con una `@ruta` a la que le falta un
#   carácter parsea a CERO ramas, se guarda sin quejarse y el agente contesta como
#   si no tuviera configuración. Nadie se entera hasta que un cliente se queja.
#
# POR QUÉ NO REIMPLEMENTA LAS REGEX:
#   Se llama al parser REAL de producción —RouteMap, Directives, TicketCreator— en
#   vez de copiar sus patrones. Eso cambia lo que significa "válido": deja de ser
#   "un modelo cree que está bien" y pasa a ser "el motor ya lo leyó, y encontró
#   esto". Una copia se desincronizaría en silencio, que es el defecto que este
#   servicio existe para cazar.
#
# LOS MENSAJES SON PARTE DEL MOTOR, NO COSMÉTICA:
#   Medido el 08/09/2026 sobre el mismo Entrenamiento roto y el mismo modelo: con un
#   mensaje-veredicto ("no hay ninguna línea @ruta") la IA lo reparó 1 de 3 veces —
#   miraba su propio texto, veía `@ruta(`, y concluía que el validador se equivocaba.
#   Con un mensaje que decía QUÉ carácter faltaba y DÓNDE, 3 de 3.
#   Por eso cada hallazgo lleva cuatro cosas: dónde, qué pasa, por qué y qué se
#   escribió. Un veredicto pelado es un bug.
#
# SEVERIDADES:
#   blocking  — si falla, esa parte del agente NO EXISTE. Impide guardar.
#   degrading — funciona, pero mal. Avisa y deja guardar.
#   cosmetic  — mejora la calidad de la redacción, no rompe nada.
# ================================================================================

class ContactTrackings::Assistant::ValidatorService
  # Directivas de ACCIÓN. Nunca son la fuente de una rama: si aparecen del lado
  # izquierdo de la flecha, es que la flecha no está o está mal escrita.
  ACTION_RE = /@crear_ticket\b|@estado_ticket\b|@agendar_calendar\b/i

  def initialize(text, account:)
    @text = text.to_s
    @account = account
    @map = ContactTrackings::RouteMap.parse(@text)
    @findings = ContactTrackings::Assistant::Findings.new
  end

  # El orden importa en un solo punto: las líneas @ruta que no parsean van primero,
  # porque su diagnóstico suprime el genérico "0 ramas" (decirle a alguien que no
  # escribió ninguna @ruta cuando la escribió mal es lo que hace que descarte el aviso).
  CHECKS = %i[
    check_pending_markers check_contract_leftovers check_structure
    check_unparsed_route_lines check_has_routes
    check_route_sources check_route_lines check_action_in_source check_ticket_types check_default_route
    check_descriptions check_duplicate_descriptions check_tags_exist check_corpus
    check_erp_directive_isolation
    check_escalation_regime check_calendar_directive check_prose
  ].freeze

  def call
    CHECKS.each { |check| send(check) }

    {
      routes: ContactTrackings::Assistant::RouteReport.new(map).call,
      default_route: @map.default&.name,
      blocking: findings.of(:blocking),
      degrading: findings.of(:degrading),
      cosmetic: findings.of(:cosmetic),
      valid: findings.of(:blocking).empty?
    }
  end

  private

  attr_reader :text, :account, :map, :findings

  delegate :add, to: :findings

  # Los mensajes viven en config/locales/tracking_assistant.*.yml. El idioma se
  # resuelve a uno de los dos soportados, sin depender del fallback de Rails (que
  # solo está configurado en production y staging — ver Assistant::Language).
  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end

  # ── B2 · una línea que quiso ser @ruta y el motor no reconoce ────────────────
  # Va PRIMERO porque es la falla más cara: el texto se ve perfecto y el motor lee
  # cero ramas. Y es la que exige el diagnóstico más fino — decir "falta un @ruta"
  # cuando la línea empieza con `@ruta(` hace que el lector piense que el error es
  # del validador.
  def check_unparsed_route_lines
    text.lines.each_with_index do |raw, index|
      line = raw.rstrip
      next unless line.lstrip.start_with?('@ruta(')
      next if line.match?(ContactTrackings::RouteMap::LINE_RE)

      # `route`: el nombre leído a ojo, para colgar el aviso de la rama rota en el árbol.
      add(:blocking, :route_line_unparsed,
          t('findings.route_line_unparsed', line: index + 1, reason: unparsed_reason(line)),
          line: index + 1, wrote: line.strip, route: ContactTrackings::TrainingRoutes.broken_entry(line)['name'])
    end
  end

  def unparsed_reason(line)
    return t('unparsed.no_closing_paren') unless line.include?(')')
    # Medido con una rama real (24/09): terminaba en «?)», sin nada después.
    return t('unparsed.no_source') if line.rstrip.end_with?(')') && line.count('(') == line.count(')')
    # El caso que se midió: `@ruta(...)` seguido de la fuente sin los dos puntos.
    return t('unparsed.no_colon') if line.match?(/@ruta\([^)]*\)\s*[^:\s]/)
    return t('unparsed.bad_name') if line.match?(/@ruta\(\s*[^a-z0-9_\-#:)]/i)

    t('unparsed.generic')
  end

  # B11 (directiva sin cerrar) y D9 (rama que no hace nada): ver RouteLineChecks.
  def check_route_lines
    ContactTrackings::Assistant::RouteLineChecks.new(map, findings: findings).call
  end

  # Comprobar la configuración contra lo que la cuenta TIENE es otro tipo de
  # pregunta que comprobar la gramática, y vive aparte.
  def check_corpus
    ContactTrackings::Assistant::CorpusChecks.new(map, account: account, findings: findings).call
  end

  # Las reglas de la ZONA 2 viven en ProseChecks: es la división que hace el propio
  # contrato, y escriben en el mismo colector, así que para quien consume el
  # resultado sigue habiendo un solo comprobador.
  def check_prose
    ContactTrackings::Assistant::ProseChecks.new(text, map: map, findings: findings).call
  end

  # ── B9 · datos por completar (ver PendingMarkers) ───────────────────────────
  def check_pending_markers = ContactTrackings::Assistant::PendingMarkers.check(text, findings: findings)

  # ── B10 · restos del contrato (ver ContractLeftovers) ────────────────────────
  def check_contract_leftovers = ContactTrackings::Assistant::ContractLeftovers.check(text, findings: findings)

  # S1–S4: lo mal escrito a mano fuera de las rutas (ver StructureChecks).
  def check_structure = ContactTrackings::Assistant::StructureChecks.check(text, findings: findings)

  def pending?(value) = ContactTrackings::Assistant::PendingMarkers.pending?(value)

  # ── B1 · ninguna rama ───────────────────────────────────────────────────────
  def check_has_routes
    return if map.present?
    # Si ya se explicó línea por línea por qué no parsean, no se repite el genérico.
    return if findings.code?(:route_line_unparsed)

    add(:blocking, :no_routes, t('findings.no_routes'))
  end

  # ── B4 y B5 · la fuente de cada rama ────────────────────────────────────────
  def check_route_sources
    map.routes.each do |route|
      next if route.directive.blank? # "-" es válido: la rama no consulta nada
      next if pending?(route.directive) # falta elegirla: lo dice check_pending_markers

      detected = KnowledgeBase::Directives.detect(route.directive)
      if detected.nil?
        add(:blocking, :unknown_source, t('findings.unknown_source', route: route.name),
            wrote: route.directive, route: route.name)
        next
      end

      check_named_source_exists(route, detected)
    end
  end

  # El nombre de @buscar_foro(X) y {{doc:X}} direcciona una fuente concreta. Si no
  # coincide con ninguna, el motor no falla: busca y no encuentra, siempre.
  def check_named_source_exists(route, detected)
    name = detected[:source_name]
    return if name.blank?
    return if account.knowledge_sources.active.any? { |s| s.name.casecmp?(name) }

    disponibles = account.knowledge_sources.active.map(&:name)
    add(:blocking, :source_not_found,
        t('findings.source_not_found', route: route.name, name: name,
                                       available: listado(disponibles, 'findings.source_none_loaded')),
        wrote: route.directive, route: route.name)
  end

  # ── B8 · una acción atrapada dentro de la fuente ────────────────────────────
  # Salió de una corrida real: el modelo escribió "- 3e" en vez de "->", así que
  # RouteMap no partió la línea y todo quedó como fuente. `detect` igual encontró
  # @buscar_articulo adelante y dio la rama por buena — con el @crear_ticket adentro,
  # inerte. El agente que se pidió para abrir tickets no abría ninguno, y nada lo
  # marcaba: un escalamiento vacío es perfectamente legal.
  def check_action_in_source
    map.routes.each do |route|
      next if route.directive.blank? || pending?(route.directive)

      match = route.directive.match(ACTION_RE)
      next if match.nil?

      add(:blocking, :action_trapped_in_source,
          t('findings.action_trapped_in_source', route: route.name, directive: match[0]),
          wrote: route.directive, route: route.name)
    end
  end

  # ── B6 · el tipo de caso de @crear_ticket ───────────────────────────────────
  def check_ticket_types
    tipos = CaseType.where(account_id: account.id).pluck(:name)

    text.scan(/@crear_ticket\(([^)]*)\)/i).flatten.each do |args|
      tipo = args[/tipo\s*=\s*([^,)]+)/i, 1]&.strip
      next if tipo.blank? || pending?(tipo) || tipos.any? { |t| t.casecmp?(tipo) }

      add(:blocking, :case_type_not_found,
          t('findings.case_type_not_found', type: tipo, available: listado(tipos, 'findings.case_type_none_created')),
          wrote: "tipo=#{tipo}")
    end
  end

  # "Los que existen: A · B" o, si no hay ninguno, el texto que lo dice. Sin esto,
  # el aviso termina en "Los que existen: ." y quien lee no sabe si es que no hay
  # ninguno o si el comprobador se quedó a medias.
  def listado(valores, clave_vacia, sep: ' · ')
    valores.presence&.join(sep) || t(clave_vacia)
  end

  # ── B7 · la rama por defecto ────────────────────────────────────────────────
  def check_default_route
    declared = text[ContactTrackings::RouteMap::DEFAULT_RE, 1]&.downcase
    return if declared.blank?
    return if map.names.include?(declared)

    add(:blocking, :default_route_unknown,
        t('findings.default_route_unknown', declared: declared,
                                            routes: listado(map.names, 'findings.default_route_no_routes', sep: ', ')),
        wrote: "@ruta_por_defecto: #{declared}")
  end

  # ── D1 · rama sin descripción ───────────────────────────────────────────────
  def check_descriptions
    map.routes.each do |route|
      next if route.description.present?

      add(:degrading, :route_without_description,
          t('findings.route_without_description', route: route.name),
          wrote: "@ruta(#{route.name}...)", route: route.name)
    end
  end

  # ── D8 · dos ramas que dicen lo mismo ───────────────────────────────────────
  # Salió de una corrida real del Asistente: escribió dos ramas —"gestiones" y
  # "humano"— con la MISMA descripción, "quiero hablar con un asesor". El
  # clasificador no las puede distinguir, así que una de las dos no se elige
  # nunca, y cuál de las dos pierde lo decide el orden en que el modelo las mire.
  #
  # Es comprobable sin IA: la descripción es texto, y comparar texto es gratis.
  # Por eso va acá y no en la comprobación de ruteo, que cuesta una llamada por
  # rama.
  def check_duplicate_descriptions
    # Varias "<PENDIENTE: frases>" iguales no son descripciones repetidas: son
    # descripciones que todavía no existen.
    con_descripcion = map.routes.select { |r| r.description.present? && !pending?(r.description) }

    con_descripcion.group_by { |r| normalizar(r.description) }
                   .each_value { |grupo| report_duplicate(grupo) unless grupo.one? }
  end

  def report_duplicate(grupo)
    add(:degrading, :duplicate_route_description,
        t('findings.duplicate_route_description', routes: grupo.map(&:name).join(', ')),
        wrote: grupo.first.description, routes: grupo.map(&:name))
  end

  # Se comparan sin tildes, sin mayúsculas y sin puntuación: "no puedo entrar" y
  # "No puedo entrar." son la misma descripción para quien lee, y para el
  # clasificador también.
  def normalizar(texto)
    texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase.gsub(/[^a-z0-9 ]/, ' ').squish
  end

  # ── D2 · la etiqueta no existe ──────────────────────────────────────────────
  # También la sección [ETIQUETAS] como diccionario de estados: ver TagDictionary.
  def check_tags_exist
    ContactTrackings::Assistant::TagDictionary.check(text, map: map, account: account, findings: findings)
    existentes = account.labels.pluck(:title)

    map.routes.each do |route|
      next if route.tag.blank?
      next if existentes.any? { |t| t.casecmp?(route.tag) }

      add(:degrading, :label_not_found,
          t('findings.label_not_found', tag: route.hashtag, route: route.name,
                                        available: listado(existentes, 'findings.label_none_created')),
          wrote: route.hashtag, route: route.name)
    end
  end

  # ── D4, B9, B10 · {{consulta:}} (proyecto@erp_productos): ver ErpChecks ─────
  def check_erp_directive_isolation
    ContactTrackings::Assistant::ErpChecks.new(text, map: map, account: account, findings: findings).call
  end

  # ── D7 · @agendar_calendar sin ningún calendario en la cuenta ───────────────
  # El motor solo agenda si el AGENTE tiene calendarios asignados
  # (appointment_dispatchable? exige calendar_configured?). Escrita sin eso, la
  # directiva parsea, el comprobador la ve bien, y no agenda nada: silencio otra
  # vez.
  #
  # Acá se comprueba lo único comprobable sobre un borrador sin guardar: que la
  # cuenta tenga al menos un calendario conectado. Si no tiene ninguno, la
  # directiva no puede funcionar en ningún agente.
  #
  # Es DEGRADANTE y no bloqueante, a diferencia de una fuente que no existe: el
  # agente sigue contestando y sigue abriendo casos, lo único que no pasa es el
  # agendado. Y se arregla en los ajustes de Chatwoot, no en el Entrenamiento —
  # bloquear el guardado dejaría a alguien sin poder redactar el agente hasta
  # terminar de conectar Google.
  def check_calendar_directive
    return unless text.match?(/@agendar_calendar\b/i)
    return if UserCalendarIntegration.exists?(account_id: account.id)

    add(:degrading, :calendar_not_configured, t('findings.calendar_not_configured'),
        wrote: '@agendar_calendar')
  end

  # ── D5 · régimen de escalamiento mixto ──────────────────────────────────────
  # Si UNA rama lleva flecha, el motor cambia de régimen y las ramas sin flecha
  # dejan de abrir casos, aunque haya un @crear_ticket global.
  def check_escalation_regime
    return unless map.escalations?

    sin_flecha = map.routes.reject(&:escalates?).map(&:name)
    return if sin_flecha.empty?

    add(:degrading, :mixed_escalation_regime,
        t('findings.mixed_escalation_regime', routes: sin_flecha.join(', ')))
  end
end
