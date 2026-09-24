# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE SE COMPRUEBA SIN IA EN UNA RESPUESTA DEL BOT
# ================================================================================
# Parte de la revisión de conversaciones reales (ConversationReview). Medido el 24/09
# con la 173: gpt-4o daba por buenas respuestas con «#humano» y con «Ya tenés», aun
# viéndolas marcadas. Lo que se puede comprobar se comprueba acá y sale como hallazgo
# por su cuenta; el modelo juzga el resto.
#
#   voseo      tenés, querés, preferís… Al cliente se le habla de tú (CustomerTone).
#              Causa: el Entrenamiento si él mismo está en voseo (el modelo lo
#              imita); si no, el motor (sus textos fijos, corregidos el 24/09).
#   wrong_tag  la respuesta lleva una #etiqueta que no es la de su ruta. La etiqueta en
#              el texto NO es error por sí sola: el motor la pone a propósito
#              (with_branch_tag) y dispara las automatizaciones. Es error cuando no es
#              la de la ruta del mensaje que se está contestando (la 173: una sección
#              general de etiquetas le pegaba #humano a todo).
# ================================================================================

class ContactTrackings::Assistant::ReplySignals
  VOSEO_RE = /\b(vos|ten[eé]s|quer[eé]s|pod[eé]s|prefer[ií]s|sab[eé]s|necesit[aá]s|decime|contame|avisanos|escrib[ií](?=\s))\b/i
  TAG_RE = /(?<![\w&])#([\p{L}\d_]+)/

  # ran: el Entrenamiento con que se contestó; current: el actual del agente, si cambió.
  def initialize(ran:, current: nil)
    @ran = ran.to_s
    @current = current.to_s.presence
  end

  # replay: lo que DryRunService dice del mensaje del cliente que se contesta, o nil.
  def call(texto, replay)
    [voseo(texto), wrong_tag(texto, replay)].compact
  end

  # Para el modelo, en una línea.
  def self.describe(signal)
    case signal[:code]
    when 'voseo' then "voseo (#{signal[:words].join(', ')})"
    when 'wrong_tag' then "lleva #{signal[:tags].join(' ')} y la etiqueta de su ruta (#{signal[:route]}) es #{signal[:expected]}"
    end
  end

  private

  def voseo(texto)
    palabras = texto.scan(VOSEO_RE).flatten.map(&:downcase).uniq
    return nil if palabras.empty?

    { code: 'voseo', words: palabras, cause: @ran.match?(VOSEO_RE) ? 'entrenamiento' : 'motor' }
  end

  def wrong_tag(texto, replay)
    puestas = texto.scan(TAG_RE).flatten.map { |e| "##{e.downcase}" }.uniq
    esperada = replay && replay[:tag].to_s.downcase.presence
    return nil if esperada.nil? || puestas.empty? || puestas.include?(esperada)

    { code: 'wrong_tag', tags: puestas, expected: esperada, route: replay.dig(:routes, :chosen),
      cause: 'entrenamiento', already_fixed: fixed_in_current?(puestas) }
  end

  # El agente ya no tiene esas etiquetas: se corrigió, pero a esta conversación no le
  # llega (usa su copia).
  def fixed_in_current?(tags)
    return false if @current.nil?

    tags.none? { |tag| @current.downcase.include?(tag) }
  end
end
