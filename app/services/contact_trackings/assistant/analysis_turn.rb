# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL TURNO DE «ANALIZA MI PROMPT» (y el botón de corregir)
# ================================================================================
# Lo que el Asistente hace sin IA alrededor del análisis de un Entrenamiento que ya
# existe (CheckerSection le pasa al modelo los hallazgos; esto decide qué se muestra):
#
#   reply       la respuesta a un pedido de análisis empieza SIEMPRE con lo que marca el
#               comprobador (25/09/2026: con 6 avisos, el modelo contestó pidiendo que
#               le dijeran qué revisar). Debajo va la lectura del modelo.
#   fix_offer   si hay avisos que se arreglan escribiendo, el botón para corregirlos.
#   guard       tras corregir con el botón, las líneas @ruta sin un aviso corregible
#               vuelven a quedar como estaban (24/09/2026: la corrección cambió la fuente
#               de dos rutas por <PENDIENTE: fuente> y, en otra vuelta, por el foro de
#               otra empresa, porque en la cuenta de prueba la hoja no existía).
# ================================================================================

class ContactTrackings::Assistant::AnalysisTurn
  Checker = ContactTrackings::Assistant::CheckerSection
  MAX_ITEMS = 25

  # said: el último mensaje de la persona.
  def initialize(account, draft:, said:, editing:, building:)
    @account = account
    @draft = draft
    @said = said.to_s
    @editing = editing
    @building = building
  end

  def result
    return nil unless @editing

    @result ||= Checker.result(@draft, @account)
  end

  def reply(mensaje)
    return mensaje unless analysis_request? && result

    [findings_block, own_reading(mensaje)].compact_blank.join("\n\n")
  end

  # [{ question:, choices: }] o nil.
  def fix_offer
    return nil if @building || !analysis_request? || result.nil? || fixable.empty?

    [{ question: t('fix_offer.question', count: fixable.size), choices: [t('fix_offer.yes')] }]
  end

  def fix_request?
    @editing && @said.include?(t('fix_offer.yes'))
  end

  def guard(antes, despues)
    corregibles = fixable.flat_map { |f| f[:routes] || [f[:route]] }.compact
    originales = route_lines(antes)
    despues.to_s.split("\n", -1).map do |linea|
      nombre = route_name(linea)
      nombre && originales.key?(nombre) && corregibles.exclude?(nombre) ? originales[nombre] : linea
    end.join("\n")
  end

  private

  def analysis_request?
    @said.match?(Checker::ANALYSIS_RE)
  end

  def findings
    Array(result && (result[:blocking].map { |f| f.merge(mark: '🔴') } + result[:degrading].map { |f| f.merge(mark: '🟡') }))
  end

  def fixable
    findings.select { |f| Checker::FIXABLE.include?(f[:code]) }
  end

  # Agrupada por situación (25/09/2026: 18 avisos eran 7 etiquetas, 6 directivas y 3
  # rutas, cada una con el párrafo entero): qué pasa y qué hacer una sola vez, y a qué
  # afecta. Un aviso sin compañeros va completo, que trae más detalle.
  GROUPS = { route_does_nothing: 'nothing', label_not_found: 'labels', state_label_not_found: 'labels',
             loose_directive: 'loose', bare_tag_line: 'bare_tags', source_not_found: 'sources' }.freeze

  def findings_block
    return t('analysis.clean') if findings.empty?

    grupos = findings.group_by { |f| GROUPS[f[:code]] || f.object_id }
    lineas = grupos.values.first(MAX_ITEMS).map { |lista| group_line(lista) }
    ([t('analysis.header', count: findings.size)] + lineas).join("\n")
  end

  def group_line(lista)
    primero = lista.first
    clave = GROUPS[primero[:code]]
    return "- #{primero[:mark]} #{primero[:message].to_s.squish.truncate(Checker::MAX_MESSAGE)}" if clave.nil? || lista.one?

    afectados = lista.map { |f| affected(f) }.uniq.join(' · ')
    "- #{primero[:mark]} #{t("analysis.groups.#{clave}", count: lista.size)}\n  #{afectados}"
  end

  def affected(finding)
    case finding[:code]
    when :label_not_found, :state_label_not_found then finding[:wrote].to_s
    when :loose_directive then t('analysis.line', line: finding[:line], wrote: finding[:wrote])
    when :source_not_found then "#{finding[:route]} → #{finding[:wrote]}"
    else Array(finding[:routes] || finding[:route]).join(', ').presence || t('analysis.line', line: finding[:line], wrote: '')
    end.strip
  end

  # Lo que el modelo escribió, sin los avisos que repite (la lista ya va arriba):
  # medido el 25/09 con 18 avisos, los volvió a copiar uno por uno antes de su lectura.
  REPEATED_RE = /\A\s*(?:[-*•]\s*)?(?:\*\*)?(?:ROJO|ÁMBAR|AMBAR|🔴|🟡)\b/i

  def own_reading(mensaje)
    lineas = mensaje.to_s.lines.grep_v(REPEATED_RE)
    lineas.join.gsub(/\n{3,}/, "\n\n").strip
  end

  def route_lines(texto)
    texto.to_s.split("\n").each_with_object({}) { |linea, acc| (n = route_name(linea)) && acc[n] ||= linea }
  end

  def route_name(linea)
    linea[/\A\s*@ruta\(\s*([a-z0-9_-]+)/i, 1]&.downcase
  end

  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
