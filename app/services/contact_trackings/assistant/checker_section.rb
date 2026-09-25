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
# FIXABLE, ANALYSIS_RE y ACCOUNT_BOUND los usa AnalysisTurn (la lista, el botón de
# corregir y su candado); RECIPES es cómo se corrige cada aviso cuando lo piden.
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
    - Un MAPA de fuentes en la prosa («SOPORTE: @discourse. COMERCIAL: @buscar_predefinidas»): no lo reemplaces
      (quedaría «SOPORTE: la información consultada. COMERCIAL: la información consultada»); bórralo, porque ese
      mapa lo hacen las líneas @ruta, y deja la regla de fondo («lo que afirmes de la empresa sale solo de la
      información consultada»). Si a algún tipo del mapa le falta su ruta con esa fuente, dilo en el mensaje.
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
      Si piden analizar o revisar el prompt, NUNCA pidas que aclaren qué revisar, y NO repitas
      esta lista: ya se le muestra a la persona arriba de tu mensaje, agrupada. Tu mensaje es
      solo «Mi lectura:», de 3 a 5 puntos que NO sean estos avisos (contradicciones, reglas
      vagas, lo que falta, lo que el comprobador no puede ver).

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
