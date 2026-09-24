# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — NO SIMULAR: LO QUE EL ENTRENAMIENTO PROMETE Y NO PASA
# ================================================================================
# Del manual de estructura (24/09/2026) y de la conversación 173: el agente dijo «te
# confirmo en un momento» y nadie confirmó nada. No hay seguimiento automático: lo
# que el agente promete hacer después, no pasa.
#
#   P1 acción sin su directiva   [ALCANCE POR RAMA] dice que una rama agenda, cancela
#                                o mueve citas, o que abre un caso, y el Entrenamiento
#                                no tiene la directiva que lo hace (@agendar_calendar,
#                                @crear_ticket). El motor las busca en todo el texto,
#                                así que basta con que estén en alguna rama. El borrador
#                                #2923 decía «Agenda la cita en el calendario» sin
#                                ninguna @agendar_calendar.
#   P2 promesa de seguimiento    la prosa le pide al agente decir «te confirmo en un
#                                momento», «lo estoy revisando», «te mantendré
#                                informado»… Salvo que la línea lo prohíba (nunca, no,
#                                evita, prohibido): ahí está bien escrito.
#
# Ámbar los dos: el agente contesta; lo que falla es lo que promete.
# ================================================================================

module ContactTrackings::Assistant::PromiseChecks
  SCOPE_RE = /\A[ \t]*\[\s*ALCANCE POR RAMA\s*\][ \t]*\z/i
  ACTIONS = {
    'calendar' => { says: /\b(agend|reagend|reprogram|calendario|(cancel|mov|modific|cambi)\w*\s+(la\s+|tu\s+|su\s+)?cita)/i,
                    directive: /@agendar_calendar\b/i },
    'ticket' => { says: /\b(abr[eai]\w*|levant\w*|crea\w*|gener\w*)\s+(un\s+|el\s+)?(caso|ticket|reporte)\b/i,
                  directive: /@crear_ticket\b/i }
  }.freeze
  FOLLOW_UP_PHRASES = [
    'te\\s+confirmo\\s+en\\s+(un|breve)', 'lo\\s+estoy\\s+revisando', 'estoy\\s+revisando',
    'te\\s+mantendr[eé]\\s+informad', 'estar[eé]\\s+pendiente', 'en\\s+breve\\s+te\\s+(confirmo|aviso|escribo)',
    'te\\s+aviso\\s+en\\s+cuanto'
  ].freeze
  FOLLOW_UP_RE = /\b(#{FOLLOW_UP_PHRASES.join('|')})/i
  NEGATION_RE = /\b(nunca|no|evita\w*|prohib\w*|jam[aá]s|sin)\b/i

  module_function

  def check(text, map:, findings:)
    lineas = text.to_s.split("\n", -1)
    scope_lines(lineas).each { |numero, linea| action_without_directive(text, map, numero, linea, findings) }
    lineas.each_with_index { |linea, indice| follow_up_promise(linea, indice + 1, findings) }
  end

  # [[número, línea]] del cuerpo de [ALCANCE POR RAMA].
  def scope_lines(lineas)
    inicio = lineas.index { |linea| linea.match?(SCOPE_RE) }
    return [] if inicio.nil?

    lineas.each_with_index.drop(inicio + 1)
          .take_while { |linea, _| !linea.match?(ContactTrackings::Assistant::DraftPieces::SECTION_RE) }
          .filter_map { |linea, indice| [indice + 1, linea] if linea.include?(':') }
  end

  def action_without_directive(text, map, numero, linea, findings)
    etiqueta, que_hace = linea.split(':', 2)
    ACTIONS.each do |accion, reglas|
      next unless que_hace.to_s.match?(reglas[:says]) && !text.match?(reglas[:directive])

      findings.add(:degrading, :promised_action_missing,
                   t("promised_action_missing.#{accion}", line: numero, route: etiqueta.strip),
                   line: numero, wrote: linea.strip, route: route_for(map, etiqueta))
    end
  end

  # «Agendar cita» → agendar_cita, «Clase de prueba» → clase_prueba, si esa rama existe.
  CONNECTORS = %w[de del la el los las y en para].freeze

  def route_for(map, etiqueta)
    palabras = I18n.transliterate(etiqueta.to_s.strip.downcase).split(/[\s_-]+/)
    [palabras, palabras - CONNECTORS].map { |p| p.join('_') }.find { |nombre| map.names.include?(nombre) }
  end

  def follow_up_promise(linea, numero, findings)
    return unless linea.match?(FOLLOW_UP_RE) && !linea.match?(NEGATION_RE)

    findings.add(:degrading, :follow_up_promise, t('follow_up_promise', line: numero),
                 line: numero, wrote: linea.strip)
  end

  def t(key, **args)
    I18n.t("tracking_assistant.findings.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
