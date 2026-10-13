# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA PILA DE PRUEBAS: CALIFICAR (M5 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Una respuesta real del agente contra lo que tenía que cumplir: la «Verificación» de la
# regla (o la ruta esperada) y, siempre, el [ESTILO] y el [PROHIBIDO] del Entrenamiento.
# En la pila a mano de ADAM eso fue lo que se miró: usted o tú, una sola pregunta, sin
# precios, sin prometer acciones que no hace.
#
# La ruta no la califica la IA: la dice la #etiqueta con la que cerró (código).
#
# P2 · 3.4a (13/10/2026): en F0 este juez inventaba fallas. Ahora:
#   · lo que se puede contar (preguntas, renglones, párrafos, emojis, cierre) lo cuenta
#     StyleCounts, sin IA; la IA recibe el [ESTILO] SIN esas oraciones (con ellas a la
#     vista las seguía contando aunque se le prohibiera);
#   · se califica lo que escribió el agente: lo que agregó el sistema (etiqueta, firma,
#     enlace del foro, horarios del calendario, lista de servicios) va aparte (ReplyParts);
#   · la IA sabe qué día es hoy («el 13 de octubre no es martes en 2023»);
#   · un dato que la IA no puede comprobar (placas, horas) no reprueba: va en `por_revisar`.
#     Marcaba «inventó la placa 92UN8A» sin saber qué traía la hoja del agente; ahora el
#     código busca antes esos datos en las hojas de la cuenta (SheetFacts) y se los pasa;
#   · en qué ruta cayó lo dice solo el código (la #etiqueta): la IA decía «no siguió la ruta X»
#     sin conocer su definición, en pruebas que sí cayeron en X. Cómo atendió se califica
#     contra la línea de esa ruta en [ALCANCE POR RAMA].
# cumple = sin fallas contadas y la IA dice que cumple. Un «preferentemente…» del [ESTILO]
# no reprueba: sale en `avisos`.
# ================================================================================

class ContactTrackings::Assistant::TestBatteryJudge
  SECTION_RE = ->(nombre) { /^\[#{nombre}\]\s*\n(.*?)(?=^\[[A-ZÁÉÍÓÚÑ ]+\]\s*$|\z)/m }
  TAG_RE = /#([a-z0-9_]+)/i
  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  PROMPT = <<~PROMPT
    Calificas UNA respuesta de un agente de IA que atiende clientes por chat. Recibes lo que
    escribió el cliente, lo que contestó el agente, lo que esa prueba tenía que cumplir y las
    reglas de estilo y prohibiciones del agente. Sé estricto y concreto: una falla es algo que
    la respuesta hace o deja de hacer, citando la parte.

    NO califiques ni menciones lo que se cuenta: cuántas preguntas hace, cuántas líneas o
    párrafos tiene, cuántos emojis trae ni si termina en pregunta. Eso ya lo contó el código.
    Lo AGREGADO POR EL SISTEMA es real y no lo escribió el agente: la etiqueta, la firma, los
    enlaces del foro, los horarios del calendario y la lista de servicios salen del sistema.
    No los marques como inventados ni los califiques contra su estilo. Sí cuenta si lo que
    pasó (por ejemplo, ofrecer horarios) era lo que correspondía a lo que pidió el cliente.
    Si el agente no escribió nada porque toda la respuesta la armó el sistema, eso no es falla.
    En qué ruta cayó lo mide el código por la #etiqueta: NO califiques la ruta («no siguió la
    ruta X»); en una prueba de ruta califica solo que conteste lo que pidió el cliente.
    Los DATOS QUE ESTÁN EN SUS HOJAS son reales: nunca los marques como inventados.
    Usa la fecha de HOY que te dan: no supongas otro año.
    NO SABES qué datos tenía el agente (hojas, catálogo, calendario, casos, el seguimiento):
    un dato concreto que no puedes comprobar (placas, modelos, precios, fechas, horas) NO es
    falla; va en "por_revisar", aunque el PROHIBIDO diga «nunca inventar…»: esa regla solo
    se rompe si se nota sin conocer los datos (confirmar o prometer algo que el sistema no
    hizo, contradecir al cliente o a otra regla). Casi siempre el dato salió de sus hojas.
    Contesta SOLO el JSON:
    {"cumple": true|false, "fallas": ["…"], "por_revisar": ["dato: …"], "motivo": "una línea"}
  PROMPT

  def initialize(account, training:)
    @account = account
    @estilo = training.to_s[SECTION_RE.call('ESTILO'), 1].to_s.strip
    @prohibido = training.to_s[SECTION_RE.call('PROHIBIDO'), 1].to_s.strip
    @alcance = training.to_s[SECTION_RE.call('ALCANCE POR RAMA'), 1].to_s.strip
    @counts = ContactTrackings::Assistant::StyleCounts.new(@estilo)
  end

  # reply: los mensajes del agente, uno por uno (o todos en un texto).
  # { cumple:, fallas: [], avisos: [], por_revisar: [], motivo:, ruta_ok: true|false|nil, medidas: {}, agregado: [] }
  def call(scenario, reply)
    partes = ContactTrackings::Assistant::ReplyParts.new(reply)
    return { cumple: false, fallas: ['No contestó.'], motivo: 'Sin respuesta del agente.' } if partes.blank?

    contado = @counts.call(partes.body)
    raw = ask(scenario, partes)
    modelo = raw.is_a?(Hash) ? raw : {}
    { cumple: verdict(contado, modelo), fallas: contado[:fallas] + Array(modelo['fallas']).map(&:to_s), avisos: contado[:avisos],
      por_revisar: unverified(modelo['por_revisar']),
      motivo: raw.is_a?(Hash) ? modelo['motivo'].to_s : 'No se pudo calificar.', ruta_ok: route_ok(scenario, Array(reply).join("\n\n")),
      medidas: contado[:medidas], agregado: partes.added_labels }
  end

  attr_reader :usage

  private

  # Con una falla contada no cumple, diga lo que diga la IA. Sin ella, decide la IA (nil si no contestó).
  def verdict(contado, modelo)
    return false if contado[:fallas].any?
    return nil unless modelo.key?('cumple')

    modelo['cumple'] == true
  end

  def ask(scenario, partes)
    @facts = ContactTrackings::Assistant::SheetFacts.new(@account).call(partes.body)
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    raw = chat.call([{ role: 'system', content: PROMPT }, { role: 'user', content: question(scenario, partes) }],
                    max_tokens: 600, temperature: 0.0)
    @usage = chat.last_usage
    raw
  end

  def question(scenario, partes)
    hechos = @facts.map { |dato, hoja| "#{dato} (hoja #{hoja})" }.join(', ')
    agregado = partes.added.map { |a| "· #{a['que']}: #{a['texto']}" }.join("\n")
    <<~TXT
      HOY: #{today}
      CLIENTE: #{scenario.message}
      AGENTE (lo que escribió): #{or_else(partes.body, '(nada: toda la respuesta la armó el sistema, no es falla)')}
      DATOS QUE ESTÁN EN SUS HOJAS: #{or_else(hechos, '(ninguno)')}
      AGREGADO POR EL SISTEMA:
      #{or_else(agregado, '(nada)')}
      TENÍA QUE CUMPLIR: #{expected(scenario)}
      ESTILO DEL AGENTE:
      #{or_else(@counts.uncounted, '(nada más que lo ya contado)')}
      YA LO VERIFICÓ EL CÓDIGO (no lo califiques): #{or_else(counted, '(nada)')}
      PROHIBIDO PARA EL AGENTE:
      #{or_else(@prohibido, '(no tiene)')}
    TXT
  end

  def or_else(texto, vacio) = texto.presence || vacio

  # «Que atienda como la ruta X» hacía que la IA juzgara la ruta solo por su nombre; «que conteste
  # lo que pidió» reprobaba a ADAM por preguntar antes de recomendar, que es lo que su ruta pide.
  # Se califica contra lo que el Entrenamiento pide en esa ruta ([ALCANCE POR RAMA]).
  def expected(scenario)
    return scenario.check unless scenario.kind == 'ruta'

    alcance = route_scope(scenario.route)
    return "Que atienda como pide su Entrenamiento en esta ruta: #{alcance}" if alcance

    'Que conteste lo que pidió el cliente sin romper su estilo ni lo prohibido.'
  end

  # La línea «Nombre de la ruta: qué hace» cuyo nombre trae todas las palabras de la ruta, o al
  # revés («sistemas_trafficker_digital» ↔ «Sistemas y Trafficker Digital»). Compartir solo
  # una («confirmacion_servicio» ↔ «solicitud_servicio») no basta.
  def route_scope(ruta)
    buscadas = words(ruta)
    return nil if buscadas.empty?

    @alcance.lines.map(&:strip).find do |linea|
      nombre = words(linea.split(':', 2).first) if linea.include?(':')
      nombre.present? && ((buscadas - nombre).empty? || (nombre - buscadas).empty?)
    end
  end

  def words(texto) = I18n.transliterate(texto.to_s.downcase).split(/[^a-z0-9]+/).reject { |w| w.length < 3 }

  # Lo que ya está en sus hojas no queda «por revisar».
  def unverified(lista)
    Array(lista).map(&:to_s).reject { |dato| @facts.keys.any? { |hecho| dato.include?(hecho) } }
  end

  def counted = @counts.rules.values.map { |r| "«#{r['texto']}»" }.uniq.join(' ')

  def today
    hoy = Time.zone.today
    "#{DAYS[hoy.wday]} #{hoy.day} de #{MONTHS[hoy.month - 1]} de #{hoy.year}"
  end

  # La etiqueta con la que cerró dice la ruta. Solo en las pruebas de ruta con etiqueta.
  def route_ok(scenario, reply)
    return nil if scenario.kind != 'ruta' || scenario.tag.blank?

    reply.scan(TAG_RE).flatten.map(&:downcase).include?(scenario.tag.downcase)
  end
end
