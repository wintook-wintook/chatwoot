# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA LÍNEA DE ALCANCE DE UNA RUTA, DESDE SUS FRASES
# ================================================================================
# Pedido del usuario (25/09/2026): en el modal de una ruta, «Qué atiende esta ruta, en
# palabras del agente» se escribía a mano aunque las frases del cliente ya lo dicen.
# Esto la redacta: una línea para [ALCANCE POR RAMA], a partir del nombre, las frases,
# de dónde saca la respuesta y qué hace si no resuelve.
#
# Lo que no puede hacer: inventar datos (precios, horarios) ni prometer lo que la ruta
# no hace. Una ruta sin acción no «agenda» ni «abre un caso» (ver PromiseChecks: el
# comprobador marcaría la línea).
# ================================================================================

class ContactTrackings::Assistant::ScopeWriter
  MAX_CHARS = 160

  # route: { name:, phrases:, source:, action: } — lo que tiene el modal de la ruta.
  def initialize(account, route:, inbox: nil)
    @name = route[:name].to_s.strip
    @phrases = route[:phrases].to_s.strip.truncate(1200)
    @source = route[:source].to_s.strip
    @action = route[:action].to_s.strip
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
  end

  def call
    return { error: :blank_phrases } if @phrases.blank?
    return { error: :no_api_key } if @chat.api_key.blank?

    reply = @chat.call([{ role: 'system', content: prompt }], max_tokens: 200)
    linea = without_invented_source(reply.is_a?(Hash) ? reply['alcance'].to_s.squish.delete('[]') : '')
    linea.present? ? { scope: linea.truncate(MAX_CHARS) } : { error: :unavailable }
  end

  # Medido el 25/09: a una ruta sin fuente le puso «con las respuestas predefinidas».
  # Sin fuente, esa parte se quita.
  SOURCE_MENTION_RE = /
    \s*(?:,\s*)?(?:con|usando|utilizando|mediante|según|desde|en|a\ partir\ de|apoy[aá]ndose\ en)\s+(?:las?|los?|el)\s+
    (?:respuestas\ predefinidas|cat[aá]logo|foro[^,.]*|hoja[^,.]*|documento[^,.]*|art[ií]culos[^,.]*)
  /ix

  def without_invented_source(linea)
    @source.blank? ? linea.gsub(SOURCE_MENTION_RE, '').squish : linea
  end

  private

  def prompt
    <<~PROMPT
      Escribes UNA línea para la sección [ALCANCE POR RAMA] del Entrenamiento de un agente de atención por chat:
      qué atiende esta ruta, en palabras del agente. Empieza con un verbo en tercera persona y va sin punto final.
      Ejemplos de la forma: «responde precios y arma cotizaciones con la lista vigente», «resuelve fallas de acceso
      con el foro de soporte y abre un caso si no se resuelve», «saluda y pregunta en qué puede ayudar».

      RUTA: #{@name.presence || '(sin nombre)'}
      FRASES DEL CLIENTE (lo que la gente escribe en este tema): #{@phrases}
      DE DÓNDE SACA LA RESPUESTA: #{source_text}
      SI NO RESUELVE: #{action_text}

      Reglas:
      - Resume el TEMA de las frases, no las copies.
      - Nombra la fuente solo por lo que es («las respuestas predefinidas», «el catálogo», «el foro de soporte»),
        nunca con su directiva (@…, {{…}}). Si la ruta NO consulta ninguna fuente, no menciones ninguna.
      - No inventes datos (precios, horarios, plazos) ni prometas acciones: agendar o abrir un caso SOLO si arriba
        dice que la ruta lo hace.
      - Máximo #{MAX_CHARS} caracteres. #{ContactTrackings::Assistant::Language.name_for.capitalize}, de tú si hace falta.

      Responde SOLO un JSON: {"alcance": "..."}
    PROMPT
  end

  def source_text
    @source.presence || 'no consulta ninguna fuente (contesta con lo que dice el Entrenamiento)'
  end

  def action_text
    return 'no hace nada más: sigue conversando' if @action.blank?
    return 'abre un caso para que lo atienda una persona' if @action.match?(/@crear_ticket/i)
    return 'agenda, mueve o cancela citas en el calendario' if @action.match?(/@agendar_calendar/i)

    @action
  end
end
