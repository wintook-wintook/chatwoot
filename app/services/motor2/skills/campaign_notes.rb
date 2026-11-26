# frozen_string_literal: true

# «Campaña» (Motor2::Skills::Campaign) — lo que el código reconoce en el mensaje del contacto, sin esperar a la IA:
# la palabra clave (ya lo hizo), que pide tiempo, que solo saluda o agradece, que pide una liga (mandar_liga con la
# dirección exacta), una pregunta de un dato (no lleva la información completa) y «ahorita lo hago» (todavía no).
module Motor2::Skills::CampaignNotes
  STR = Motor2::Tools::STR

  # La nota del turno según lo que dijo (nil: ninguna de estas).
  def message_note
    return keyword_note if keyword_said?
    return LATER_NOTE if asks_time?
    return COURTESY_NOTE if @turn.last_customer.to_s.strip.match?(COURTESY)

    link_note || question_note
  end

  private

  # Solo saluda o agradece: lo de cortesía, sin preguntas ni ligas (la campaña no se empuja).
  COURTESY = /\A[\s¡!.,]*(?:hola|buen[oa]s(?:\s+(?:d[ií]as|tardes|noches))?|qu[eé]\s+tal|(?:muchas\s+|mil\s+)?gracias|ok(?:ay)?|
               perfecto|va|vale|de\s+acuerdo|listo|sale|enterad[oa]|[👍🙏😊🙂👌✅]+)[\s¡!.,😊🙂👍🙏👌✅]*\z/ix
  COURTESY_NOTE = 'Solo saludó o agradeció: contesta en corto («¡Con gusto! 😊» o «¡Hola! 😊 ¿En qué te puedo ayudar?» si es un ' \
                  'saludo sin plática antes) y NADA MÁS: sin preguntas, sin ligas, sin información ni herramientas.'

  # Pide tiempo («¿me das hasta el viernes?», «la próxima semana»): un toque más en esa fecha.
  ASKS_TIME = /\b(?:hasta\s+el|me\s+das|dame|pr[oó]rroga|m[aá]s\s+tiempo|pr[oó]xim[oa]\s+(?:semana|mes|quincena)|a\s+fin\s+de\s+mes)\b/i
  LATER_NOTE = 'Pide tiempo: PRIMERO llama mas_adelante con los días que faltan para esa fecha (sin la herramienta no se le ' \
               'vuelve a escribir) y luego despídete en una frase diciendo que le escribes entonces.'

  def asks_time? = !function.invite? && !function.survey? && @turn.last_customer.to_s.match?(ASKS_TIME)

  # Escribió la palabra clave (REGISTRADO): ya lo hizo.
  def keyword_said?
    word = function.goal == 'external' ? function.keyword.to_s.strip : ''
    word.present? && @turn.last_customer.to_s.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(word)}(?![\p{L}\p{N}])/i)
  end

  def keyword_note
    "Escribió «#{function.keyword}»: YA lo hizo. Usa ya_lo_hizo y escribe la respuesta que te da. Si además dice que tiene un " \
      'problema para entrar, usa también mandar_liga.'
  end

  # Pide «la liga» o no puede entrar: mandar_liga con la que corresponde (la dirección exacta la pone el código).
  LINK_WORDS = /\b(?:liga|link|enlace|url|acceso|no\s+me\s+lleg[oó]|no\s+(?:me\s+)?(?:abre|deja\s+entrar|puedo\s+entrar))\b/i

  def link_note
    return nil unless Array(function.links).any? && @turn.last_customer.to_s.match?(LINK_WORDS)

    'Pide una liga o no puede entrar: usa mandar_liga con la que corresponde (no busques en tus fuentes ni mandes la ' \
      'información completa otra vez).'
  end

  def link_tools
    links = Array(function.links)
    return [] if links.empty?

    uses = links.map { |l| "«#{l['name']}»: #{Motor2::Functions::CampaignSeller::LINK_USE[l['use']]}" }.join('; ')
    [fn('mandar_liga', "Pide una liga o tiene un problema para entrar: se le manda la que corresponde, exacta. #{uses}.",
        { liga: { type: 'string', enum: links.pluck('name') } }, %w[liga])]
  end

  def send_link(name)
    link = Array(function.links).find { |l| l['name'] == name.to_s } || Array(function.links).first
    trace.event(:liga, link['name'])
    @link_url = link['url']
    attach_rule('interest') # pedir la liga ya es interés: sus imágenes van con ella (una vez)
    { ok: true, nota: "Listo. Escribe en una frase «Aquí tienes la liga de #{link['name'].downcase}:» y la liga EXACTA, sin cambiarla: " \
                      "#{link['url']}. Nada más (no ofrezcas la información completa)." }
  end

  # Las ligas que van «con la información» (registro, compra, pago) salen al final aunque no estén en el texto;
  # si ya la escribieron en él, no se repite. En todos los tipos.
  def with_package_links(text)
    missing = Array(function.links).select { |l| l['use'] == 'package' && l['url'].present? && text.exclude?(l['url']) }
    missing.reduce(text.rstrip) { |all, l| "#{all}\n\n#{l['name']}: #{l['url']}" }
  end

  # Una pregunta de un dato («¿a qué hora es?», «¿cuánto cuesta?») sin pedir la información: se contesta con la ficha.
  ASKS_INFO = /\b(?:info|informaci[oó]n|detalles?|flyer|folleto|m[aá]s|cu[eé]ntame|m[aá]nd(?:a|e|ame)|env[ií](?:a|e|ame)|p[aá]sa(?:me)?)\b/i

  def concrete_question?
    text = @turn.last_customer.to_s
    text.include?('?') && !text.match?(ASKS_INFO)
  end

  # Una pregunta concreta (hora, costo, lugar…) se contesta con la ficha; la liga no es la respuesta.
  QUESTION_NOTE = 'Hizo una pregunta concreta: contéstala primero con los datos de la ficha (hora, lugar, costo…), en corto. ' \
                  'No contestes solo con la liga: mándala solo si la pide o si ya respondiste y le sirve para seguir.'

  def question_note
    QUESTION_NOTE if concrete_question?
  end

  # «Ahorita lo hago», «mañana lo pago»: todavía no lo hizo.
  WILL_DO = /\b(?:ahorita|al\s+rato|luego|despu[eé]s|m[aá]s\s+tarde|ma[nñ]ana|lo\s+(?:hago|har[eé]|pago|pagar[eé])|voy\s+a|en\s+un\s+momento)\b/i

  def will_do? = @turn.last_customer.to_s.match?(WILL_DO) && !keyword_said?

  # ---------- los toques que escribe la IA ----------

  def attempt_note
    n = @turn.tracking ? @turn.tracking.attempt_count + 1 : 1
    main = Array(function.links).find { |l| l['use'] == 'package' }
    link = main ? " y la liga «#{main['name']}» como [texto del botón](#{main['url']})" : ''
    return email_attempt_note(n, link) if email?

    n == 1 && content? ? 'Es el primer mensaje: corto, sin ligas ni la información completa; termina preguntando si le gustaría conocer más.' : ''
  end

  def email_attempt_note(touch, link)
    return "Es el PRIMER correo: lleva todo lo esencial de LA FICHA#{link}; una sola invitación a actuar al final." if touch == 1
    return "Ya dio clic en la liga pero no ha confirmado: pregúntale en corto si pudo hacerlo y ofrécele ayuda#{link}." if clicked?

    "No ha contestado: otro ángulo, más corto que el anterior#{link}."
  end

  def clicked? = @turn.tracking.present? && TrackingCampaignClick.exists?(contact_tracking_id: @turn.tracking.id)
end
