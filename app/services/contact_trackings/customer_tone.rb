# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — CÓMO LE HABLA EL BOT AL CLIENTE
# ================================================================================
# Una sola regla, para todo lo que redacta una respuesta al cliente (conversacional,
# base de conocimiento, foro, ERP, cobranza). Pedido del usuario el 24/09/2026: un
# agente contestó «Ya tenés una cita… Si querés… ¿Qué preferís?». Salía de mensajes
# fijos escritos con voseo y de instrucciones al modelo escritas con voseo, que el
# modelo imita. El producto es para México: tú, salvo que el agente pida usted.
#
# 13/11/2026 (cuenta 613, «Agente Escuela Universidad v2», convs 85 y 87): el prompt decía
# «Hablo de usted» y el bot tuteaba («te recomiendo», «puedes empezar»). RULE va al final
# del turno, el mensaje que más pesa, y lo que el modelo leía ahí era «háblale de tú»; el
# «salvo que tus instrucciones digan usted» perdía contra eso, contra las predefinidas
# escritas de tú y contra el cliente que escribe de tú. Con .rule_for el turno dice el trato
# que pide el prompt del agente, con sus palabras.
# ================================================================================

module ContactTrackings::CustomerTone
  VOSEO = 'Nunca uses voseo (vos, tenés, querés, podés, decime).'

  # Sin prompt del agente, o cuando el prompt no dice el trato.
  RULE = 'TRATO AL CLIENTE: háblale de tú, en español de México, salvo que tus instrucciones digan ' \
         "que es de usted. #{VOSEO}".freeze

  RULE_TU = "TRATO AL CLIENTE: de tú, en español de México, como piden tus instrucciones. #{VOSEO}".freeze

  RULE_USTED = 'TRATO AL CLIENTE: de USTED, como piden tus instrucciones (usted, su, le, puede, tiene, ' \
               'le comparto), aunque el cliente te escriba de tú y aunque la información de arriba o tus ' \
               "mensajes anteriores estén escritos de tú. Nunca lo tutees. #{VOSEO}".freeze

  # El prompt dice cuándo cambiar (ADAM: «de usted; solo si él te habla de tú, cambia a tú»)
  # o dice las dos cosas: el motor no impone ninguno.
  RULE_INSTRUCCIONES = 'TRATO AL CLIENTE: el que indican tus instrucciones (tú o usted, y cuándo cambiar), ' \
                       "aunque la información de arriba o tus mensajes anteriores estén escritos de otra forma. #{VOSEO}".freeze

  # Palabras que, antes de «de usted» / «de tú», dicen el trato del agente: «Hablo de usted»,
  # «SIEMPRE DE USTED», «un tono de usted», «Trato: háblale de usted». Sin «no» justo antes.
  SENAL = '(?<!\bno\s)(?<!\p{L})(?:habl\p{L}*|h\u00e1bl\p{L}*|trat\p{L}*|tr\u00e1t\p{L}*|siempre|tono|' \
          'dirij\p{L}*|dir\u00edj\p{L}*)(?!\p{L})[^.\n]{0,40}?'
  USTED_RE = /#{SENAL}\bde\s+usted(?!\p{L})/i
  TU_RE = /#{SENAL}\bde\s+t\u00fa(?!\p{L})/i
  # «si él te habla de tú, cambia a tú», «salvo que el cliente escriba de usted»: el trato cambia
  # según cómo escribe el cliente. Solo «tú» con acento: «de tu carrera» es posesivo.
  CONDICION = '(?<!\p{L})(?:si|salvo que|cuando|a menos que)(?!\p{L})[^.\n]{0,50}?'
  CONDICIONAL_RE = /#{CONDICION}(?<!\p{L})(?:habl|escrib|trat)\p{L}*\s+de\s+(?:usted|t\u00fa)(?!\p{L})/i
  STYLE_SECTION_RE = /^[ \t]*\[(?:ESTILO|TONO|TRATO)[^\]\n]*\][^\n]*\n(.*?)(?=^[ \t]*\[[^\]\n]+\][ \t]*$|\z)/mi

  module_function

  # :usted, :tu, :instrucciones (cambia según el cliente, o dice las dos cosas) o nil (no lo
  # dice). Primero en la sección de estilo, que es donde lo escribe el Asistente; si ahí no
  # está, en todo el prompt.
  def trato(prompt)
    return nil if prompt.blank?

    estilo = prompt.to_s.scan(STYLE_SECTION_RE).flatten.join("\n")
    detect(estilo) || detect(prompt.to_s)
  end

  def detect(texto)
    return :instrucciones if texto.match?(CONDICIONAL_RE)

    usted = texto.match?(USTED_RE)
    tu = texto.match?(TU_RE)
    return :instrucciones if usted && tu
    return :usted if usted
    return :tu if tu

    nil
  end

  # La regla del turno para el prompt de este agente (nil o vacío = sin agente: tú).
  def rule_for(prompt)
    return RULE if prompt.blank?

    case trato(prompt)
    when :usted then RULE_USTED
    when :tu then RULE_TU
    when :instrucciones then RULE_INSTRUCCIONES
    else RULE
    end
  end
end
