# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ¿POR QUÉ EXISTE ESTA REGLA? (fase E de PROMPT STUDIO, §30)
# ================================================================================
# La persona selecciona un fragmento del Entrenamiento y pregunta qué hace.
#
# Dos respuestas distintas, y la pantalla las muestra distintas:
#   motor          lo que el parser lee de las líneas @ruta / @ruta_por_defecto del
#                  fragmento, y si nombra una directiva que desde la prosa no se
#                  ejecuta. Es un HECHO: sale del mismo código que usa producción.
#   interpretación por qué parece estar esa regla, a qué ramas afecta y qué pasaría
#                  si se quita. Lo escribe el modelo leyendo el Entrenamiento entero:
#                  es su lectura, no una verificación.
# ================================================================================

class ContactTrackings::Assistant::Explainer
  MAX_EXCERPT_CHARS = 4000

  def initialize(account, draft:, excerpt:, inbox: nil)
    @draft = draft.to_s
    @excerpt = excerpt.to_s.strip.truncate(MAX_EXCERPT_CHARS)
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
  end

  def call
    return { error: :blank_excerpt } if @excerpt.blank?

    { section: section, engine: engine, interpretation: interpretation }
  end

  private

  # ── lo que lee el motor ─────────────────────────────────────────────────────
  def engine
    mapa = ContactTrackings::RouteMap.parse(@excerpt)
    {
      routes: mapa.routes.map { |ruta| route_facts(ruta) },
      default_route: @excerpt[ContactTrackings::RouteMap::DEFAULT_RE, 1]&.downcase,
      loose_directives: loose_directives
    }
  end

  def route_facts(ruta)
    detectada = ruta.directive && KnowledgeBase::Directives.detect(ruta.directive)
    { name: ruta.name, tag: ruta.hashtag, description: ruta.description, source: ruta.directive,
      source_mode: detectada&.dig(:mode), escalation: ruta.escalation }
  end

  # Directivas de búsqueda escritas en la prosa del fragmento: el motor no las ejecuta
  # desde ahí (ver ProseChecks D7).
  def loose_directives
    ContactTrackings::RouteMap.strip(@excerpt).scan(ContactTrackings::Assistant::ProseChecks::LOOSE_SEARCH_RE).uniq
  end

  # La sección donde está el fragmento: el último rótulo antes de su primera línea.
  def section
    primera = @excerpt.lines.first.to_s.strip
    actual = nil
    @draft.each_line do |linea|
      rotulo = linea.chomp[ContactTrackings::Assistant::DraftPieces::SECTION_RE, 1]
      actual = "[#{rotulo.strip}]" if rotulo
      return actual if linea.include?(primera)
    end
    nil
  end

  # ── la lectura del modelo ───────────────────────────────────────────────────
  def interpretation
    return nil if @chat.api_key.blank?

    reply = @chat.call([{ role: 'system', content: prompt }])
    return nil unless reply.is_a?(Hash)

    { explanation: reply['explicacion'].to_s.strip.truncate(1200).presence,
      applies_to: Array(reply['aplica_a']).map { |r| r.to_s.strip }.compact_blank.first(10),
      if_removed: reply['si_se_quita'].to_s.strip.truncate(600).presence }
  end

  def prompt
    <<~PROMPT
      Explicás, a quien administra un agente de atención al cliente, qué hace un fragmento de su Entrenamiento.

      ENTRENAMIENTO COMPLETO:
      <<<ENTRENAMIENTO
      #{@draft}
      ENTRENAMIENTO>>>

      FRAGMENTO SELECCIONADO:
      <<<FRAGMENTO
      #{@excerpt}
      FRAGMENTO>>>

      Con el Entrenamiento completo como contexto, respondé en #{ContactTrackings::Assistant::Language.name_for}, en lenguaje llano:
        explicacion   qué hace este fragmento y por qué parece estar ahí (2 a 4 frases)
        aplica_a      a qué ramas (nombres exactos de las @ruta) afecta, o [] si a todas o a ninguna en particular
        si_se_quita   qué comportamiento cambiaría si se borra (1 o 2 frases)
      Si el fragmento contradice o repite otra parte del Entrenamiento, decilo en la explicación.
      No inventes intenciones que el texto no sugiere.

      Respondé SOLO un JSON: {"explicacion": "...", "aplica_a": ["..."], "si_se_quita": "..."}
    PROMPT
  end
end
