# frozen_string_literal: true

# «Atención a clientes» › Soporte con evidencia (del prompt del Coordinador Kontrolya v5.6). Lo usa
# Motor2::Skills::Areas:
#   - judge: después de buscar, Motor2::ResultCheck dice si lo encontrado es la solución EXACTA,
#     RELACIONADA, si la fuente pide ACLARAR o NINGUNA; al agente le llega qué hacer con eso y, con una
#     exacta, el código no lo deja pasarlo ni levantar el caso antes de dar la solución;
#   - finish_reply: a una solución (exacta o relacionada) el código le agrega las «Fuentes relacionadas»
#     (las ligas tal cual vienen de la fuente; las del modelo se quitan) y las palabras para avanzar
#     (RESUELTO / ESCALAR);
#   - palabras clave: RESUELTO cierra con una despedida; ESCALAR lo pasa o levanta el caso ya;
#   - las etiquetas de la conversación: Motor2::Skills::SupportLabels;
#   - el sistema del que habla y el caso clasificado: Motor2::Skills::SupportCatalog.
#
#   memoria: state['soluciones'] (títulos ya dados), state['opciones'] (se le ofreció RESUELTO / ESCALAR)
module Motor2::Skills::SupportFlow
  include Motor2::Skills::SupportLabels
  include Motor2::Skills::SupportCatalog

  RESOLVED = /\A[\s¡!.,]*(resuelto|ya\s+qued[oó]|ya\s+(se\s+)?(funcion[oó]|resolvi[oó]|solucion[oó]|arregl[oó])|ya\s+pude|ya\s+sali[oó])\b/i
  ESCALATE = /\A[\s¡!.,]*(escalar|esc[aá]lalo|no\s+(me\s+)?(funcion[oó]|sirvi[oó]|resolvi[oó]|qued[oó])|sigue\s+(igual|sin|fallando))\b/i
  OPTIONS = "Para avanzar responde:\nRESUELTO — si quedó atendido\nESCALAR — %s"
  SOURCES = 'Fuentes relacionadas:'
  RANK = %w[ninguna relacionada aclarar exacta].freeze
  NO_LINKS = ' No pongas ligas: las agrega el código.'
  MATCH_NOTES = {
    'exacta' => 'COINCIDENCIA EXACTA (%<titulos>s). Dale la solución tal cual viene: los pasos numerados como en el documento, ' \
                'con los nombres exactos de botones, menús, casillas y opciones (entre comillas, como vienen) y las ' \
                'consideraciones que traiga. Nada de «probablemente», ni causas o pasos que no estén. No lo pases ni levantes ' \
                "caso: primero la solución.#{NO_LINKS}",
    'relacionada' => 'Solo hay información RELACIONADA (%<titulos>s): %<motivo>s. Dile que encontraste información relacionada, ' \
                     'pero no específica para lo suyo (di de qué es), y lo esencial, sin adaptarla ni suponer que aplica.' \
                     "#{NO_LINKS}",
    'aclarar' => 'Todavía no sabes cuál es su situación: NO le des soluciones ni causas todavía; hazle SOLO esta pregunta: ' \
                 '«%<pregunta>s». No lo pases ni levantes caso.',
    'ninguna' => 'No hay documentación que lo resuelva. Si lo que dijo es muy general para buscarlo, pregúntale qué le pasa ' \
                 'exactamente (una pregunta). Si ya lo dijo claro, dile: «No encontré documentación específica para darte una ' \
                 'respuesta segura sobre este caso» y %<accion>s. No inventes pasos ni causas.'
  }.freeze
  SOLUTION_FIRST = 'Todavía no: tus fuentes traen la solución exacta. Dale los pasos al cliente tal cual vienen; si después no ' \
                   'le funciona, lo pasas.'
  RESOLVED_NOTE = 'El cliente confirmó que quedó RESUELTO: agradécele en una frase y dile que aquí estás para lo que necesite. ' \
                  'Sin preguntas y sin buscar.'

  # Lo que regresó buscar_en_fuentes, revisado contra lo que pidió (solo en Soporte). nil = sin nota.
  def judge(question, found, check = nil)
    return nil unless area_key == 'support'

    many = found.count { |f| Array(f[:resultados]).any? } > 1
    check ||= Motor2::ResultCheck.new(account: config.account).call(question: question, found: found, intent: now['intencion'], many_sources: many,
                                                                    system: service_name, asked: @last_ask)
    return nil unless check

    remember_match(check, Motor2::ResultCheck.flat(found))
    trace.event(:coincidencia, "#{check['tipo']}: #{(@match['titulos'].presence || [check['motivo']]).join(' · ')}")
    { coincidencia: check['tipo'], nota: match_note(check) }
  end

  # La respuesta con las fuentes y las palabras para avanzar (solo a una solución, si no lo pasó ni levantó caso).
  def finish_reply(text)
    return text unless closing?(text)

    links = Array(@match['ligas'])
    body = without_links(text, links).sub(/\s*¿[^¿?]*\?[\s\p{Emoji_Presentation}]*\z/, '').strip.presence || text
    remember_given
    [body, sources_block(links), format(OPTIONS, escalate_text)].compact.join("\n\n")
  end

  private

  # RESUELTO / ESCALAR (o «ya quedó», «no funcionó») después de ofrecerlos; «escalar» sirve siempre.
  def keyword_turn(last_customer)
    offered = state.values.delete('opciones')
    return nil unless offered || last_customer.match?(/\A[\s¡!.,]*escalar\b/i)
    return :resolved if last_customer.match?(RESOLVED)

    :escalate if last_customer.match?(ESCALATE)
  end

  def apply_keyword(keyword)
    @resolved = keyword == :resolved
    @escalate = keyword == :escalate
    trace.event(:area, @resolved ? 'el cliente dijo que quedó resuelto' : 'el cliente pidió escalar')
  end

  def keyword_note
    return RESOLVED_NOTE if @resolved

    tool = support_case? ? 'crear_caso' : 'canalizar'
    "Pidió ESCALAR (lo que le diste no lo resolvió): llama YA #{tool} con lo que dijo y la solución que ya intentó" \
      "#{' y dale el folio' if support_case?}. No busques ni preguntes."
  end

  def remember_match(check, list)
    return if @match && RANK.index(@match['tipo']) > RANK.index(check['tipo'])

    used = check['usar'].filter_map { |i| list[i] }
    @match = { 'tipo' => check['tipo'], 'titulos' => used.filter_map { |r| r[:titulo] || r[:codigo] }.uniq,
               'ligas' => used.filter_map { |r| r[:liga].presence }.uniq }
  end

  def match_note(check)
    action = support_case? ? 'que si quiere levantas su caso con soporte' : 'que lo pasas con un asesor de soporte (llama canalizar)'
    format(MATCH_NOTES[check['tipo']], titulos: @match['titulos'].join(' · ').presence || 'en tus fuentes',
                                       motivo: check['motivo'].presence || 'no es lo mismo', accion: action,
                                       pregunta: check['pregunta'].presence || 'la que pide la fuente')
  end

  # Con una solución exacta (que no se le haya dado ya) no se pasa ni se levanta el caso todavía.
  def solution_first?
    %w[exacta aclarar].include?(@match.to_h['tipo']) && !@escalate && !human? && (@match['titulos'] - Array(state['soluciones'])).any?
  end

  def closing?(text)
    text.present? && @match && %w[exacta relacionada].include?(@match['tipo']) && !@acted && @turn.decision.nil?
  end

  def sources_block(links) = links.any? ? "#{SOURCES}\n#{links.map { |l| "- #{l}" }.join("\n")}" : nil

  # Ya se le dio esa solución (si vuelve con lo mismo, ya se puede pasar) y se le ofrecieron las palabras.
  def remember_given
    state['soluciones'] = (Array(state['soluciones']) + @match['titulos']).uniq.last(10) if @match['tipo'] == 'exacta'
    state['opciones'] = true
  end

  def escalate_text = support_case? ? 'para levantar tu caso con soporte' : 'para pasarlo con un asesor de soporte'

  # Las ligas van solo en el bloque de fuentes: se quitan del texto (y la línea que quede vacía).
  def without_links(text, links)
    links.reduce(text) do |current, link|
      current = current.gsub(/\[([^\]]*)\]\(#{Regexp.escape(link)}\)/, '\1')
      current.lines.filter_map do |line|
        next line unless line.include?(link)

        rest = line.sub(link, '').strip
        rest.match?(/\A[-•*\s]*([^:]{0,40}:)?[\s.]*\z/) ? nil : "#{rest}\n"
      end.join
    end
  end

  NO_DOCS = 'Empieza diciendo que no encontraste documentación específica para darle una respuesta segura. '

  # Soporte sin nada en sus fuentes: se le dice así antes de pasarlo o del folio.
  def no_docs_note = area_key == 'support' && @match.to_h['tipo'] == 'ninguna' ? NO_DOCS : ''
end
