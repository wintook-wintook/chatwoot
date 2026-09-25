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

    [findings_block, mensaje.to_s.strip].compact_blank.join("\n\n")
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

  def findings_block
    return t('analysis.clean') if findings.empty?

    lineas = findings.first(MAX_ITEMS).map { |f| "- #{f[:mark]} #{f[:message].to_s.squish.truncate(Checker::MAX_MESSAGE)}" }
    ([t('analysis.header', count: findings.size)] + lineas).join("\n")
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
