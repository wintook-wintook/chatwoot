# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE YA COMPROBÓ EL COMPROBADOR, PARA EL CHAT
# ================================================================================
# Pedido del usuario (24/09/2026): pegar un prompt en el editor y preguntarle al chat
# «¿qué errores tiene?». El chat contestaba con su propia lectura: podía callar un
# rojo que el comprobador marca, o llamar error a algo que no lo es.
#
# Ahora, al editar, el chat recibe los hallazgos del comprobador (ValidatorService: el
# parser real del motor, gratis y sin IA) como HECHOS, y contesta separando lo
# comprobado de su lectura. Son los mismos avisos que la persona ve en rojo y ámbar.
# ================================================================================

#
# OFRECER CORREGIR (24/09/2026): si la persona pide un análisis y hay avisos que se
# arreglan editando el texto (FIXABLE), la respuesta termina con un botón para
# corregirlos (fix_offer, sin IA: no depende de que el modelo se acuerde). Al pulsarlo,
# el chat tiene la receta de cada uno (RECIPES).
module ContactTrackings::Assistant::CheckerSection
  MAX_FINDINGS = 25
  MAX_MESSAGE = 300
  # Los que se arreglan escribiendo; no los que piden algo de la cuenta (crear una
  # etiqueta, conectar una fuente o un calendario).
  FIXABLE = %i[loose_directive unclosed_directive section_header_broken route_line_unparsed default_route_line_broken
               bare_tag_line duplicate_section loose_pending_note follow_up_promise section_ref_missing
               section_ref_title section_ref_part section_ref_name].freeze
  # Lo que depende de la cuenta: al editar no se repara solo (InterviewService#repairable).
  ACCOUNT_BOUND = %i[source_not_found case_type_not_found consulta_not_found].freeze
  # Pedidos de análisis: solo ahí se ofrece corregir (no en cada pregunta suelta).
  ANALYSIS_RE = /\b(anali[zc]|revis|observ|errore?s?|problemas?|detect|qu[eé]\s+(tiene|est[aá])\s+mal|review|analy)/i
  RECIPES = <<~RECETAS.strip
    CÓMO SE CORRIGE CADA UNO (solo si la persona pide corregirlos; nunca por tu cuenta):
    - Directiva en la prosa (@buscar_*, {{hoja:}}, {{doc:}}): cámbiala por «la información consultada» y ajusta el
      verbo para que se entienda: «ejecuta X» → «usa X», «NO ejecutes/consultes X» → «NO uses X», «al consultar X» →
      «al usar X». La búsqueda la hace el motor según la ruta; si una regla pide consultar OTRA fuente además de la
      de su ruta, quita ese paso: cada ruta consulta una sola fuente por turno.
    - Paréntesis o }} sin cerrar: ciérralo al final de la directiva.
    - Rótulo de sección roto: escríbelo [NOMBRE]. Rama por defecto sin «:»: @ruta_por_defecto: nombre.
    - Etiqueta suelta sin significado: escríbela como diccionario («#x = cuándo se usa») o bórrala.
    - Nota «PENDIENTE:» suelta: resuélvela si el texto lo permite; si no, escríbela <PENDIENTE: …>.
    - Promesa de seguimiento («te confirmo en un momento»): cámbiala por lo que sí pasa, o prohíbela.
    - Referencia a una sección que no existe: corrige el número o el nombre al de la sección que corresponde.
    Una línea @ruta solo se toca si ESE aviso de esta lista es de esa línea. NUNCA cambies la fuente de una ruta ni la
    reemplaces por <PENDIENTE:>: si una fuente no existe en esta cuenta puede existir en otra, y eso lo decide la
    persona. Lo que pide algo de la cuenta (una fuente, una etiqueta, un calendario) se deja como está.
  RECETAS

  module_function

  def result(draft, account)
    return nil if draft.to_s.strip.empty?

    ContactTrackings::Assistant::ValidatorService.new(draft, account: account).call
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pudo comprobar para el chat: #{e.message}"
    nil
  end

  # [{ question:, choices: }] para mostrar el botón, o nil.
  def fix_offer(resultado, ultimo_mensaje)
    return nil if resultado.nil? || !ultimo_mensaje.to_s.match?(ANALYSIS_RE)

    arreglables = (resultado[:blocking] + resultado[:degrading]).count { |f| FIXABLE.include?(f[:code]) }
    return nil if arreglables.zero?

    [{ question: I18n.t('tracking_assistant.fix_offer.question', count: arreglables,
                                                                 locale: ContactTrackings::Assistant::Language.resolve),
       choices: [I18n.t('tracking_assistant.fix_offer.yes', locale: ContactTrackings::Assistant::Language.resolve)] }]
  end

  # ¿El último mensaje es el botón de corregir?
  def fix_request?(texto)
    opcion = I18n.t('tracking_assistant.fix_offer.yes', locale: ContactTrackings::Assistant::Language.resolve)
    texto.to_s.include?(opcion)
  end

  # Candado sin IA para la corrección del botón (24/09/2026): el modelo cambió la fuente
  # de dos rutas por <PENDIENTE: fuente> porque en la cuenta de prueba la hoja no existía.
  # Toda línea @ruta que no tenía un aviso corregible vuelve a quedar como estaba.
  def restore_routes(antes, despues, resultado)
    corregibles = fixable_routes(resultado)
    originales = route_lines(antes)
    despues.to_s.split("\n", -1).map do |linea|
      nombre = route_name(linea)
      nombre && originales.key?(nombre) && corregibles.exclude?(nombre) ? originales[nombre] : linea
    end.join("\n")
  end

  def fixable_routes(resultado)
    return [] if resultado.nil?

    (resultado[:blocking] + resultado[:degrading]).select { |f| FIXABLE.include?(f[:code]) }
                                                  .flat_map { |f| f[:routes] || [f[:route]] }.compact
  end

  def route_lines(texto)
    texto.to_s.split("\n").each_with_object({}) { |linea, acc| (n = route_name(linea)) && acc[n] ||= linea }
  end

  def route_name(linea)
    linea[/\A\s*@ruta\(\s*([a-z0-9_-]+)/i, 1]&.downcase
  end

  def call(draft, account:, result: nil)
    resultado = result || result(draft, account)
    return nil if resultado.nil?

    <<~SECCION.strip
      ═══ LO QUE YA COMPROBÓ EL COMPROBADOR (el parser real del motor) ═══
      Son HECHOS, no opiniones, y la persona los ve marcados en pantalla (rojo: no se ejecuta;
      ámbar: funciona mal). Si te preguntan por errores o por qué algo no funciona, parte de
      esta lista: nombra cada punto con su línea o su ruta. Puedes sumar tu lectura
      (contradicciones, reglas vagas, lo que falta), pero sepárala con «Mi lectura:». Nunca
      digas que algo está bien si aparece aquí. Todo va DENTRO de "mensaje", como texto con
      viñetas: no agregues llaves nuevas al JSON.

      #{findings_text(resultado)}

      #{RECIPES}
    SECCION
  end

  def findings_text(resultado)
    lineas = { 'ROJO' => resultado[:blocking], 'ÁMBAR' => resultado[:degrading] }.flat_map do |nivel, hallazgos|
      Array(hallazgos).map { |f| "- #{nivel}#{where(f)}: #{f[:message].to_s.squish.truncate(MAX_MESSAGE)}" }
    end
    return '- Sin hallazgos: el comprobador no marca nada.' if lineas.empty?

    extra = lineas.size > MAX_FINDINGS ? ["- (y #{lineas.size - MAX_FINDINGS} más)"] : []
    (lineas.first(MAX_FINDINGS) + extra).join("\n")
  end

  # Sin repetir la línea cuando el aviso ya empieza con ella («Línea 8: …»).
  def where(finding)
    partes = []
    partes << "línea #{finding[:line]}" if finding[:line] && !finding[:message].to_s.match?(/\A(Línea|Line) \d/)
    rutas = finding[:routes] || [finding[:route]].compact
    partes << "ruta #{rutas.join(', ')}" if rutas.any?
    partes.any? ? " (#{partes.join(' · ')})" : ''
  end
end
