# frozen_string_literal: true

# Campaña con Vendedor IA — cómo escribe la IA lo que sale a quien NO ha contestado (Skills::CampaignNotes#attempt_note):
# el primer mensaje y cada toque, persuasivos según el TIPO de campaña y el número de toque, con lo que sabe de ese
# contacto y sin repetir lo anterior.
#   toque 1 (mensaje 2)   recordatorio con UN beneficio o dato concreto (según el tipo)
#   de en medio           otro ángulo: la duda u objeción más común o lo de ese contacto
#   el último             urgencia SOLO si es real (fecha, cupo, vigencia, vencimiento) y salida fácil
# Siempre: corto, una pregunta fácil, sin presionar; si ya dio clic, si pudo hacerlo.
module Motor2::CampaignPersuasion
  module_function

  ALWAYS = 'Si escribió algo hace poco, retómalo primero en una frase (si fue la respuesta automática de su WhatsApp: ' \
           'saludo, horario, «en breve te atendemos», ignórala y escribe como si no hubiera contestado). Usa lo que ' \
           'sabes de ESTE contacto (su nombre, su empresa, lo que compró o lo que le vence) si ayuda. No repitas lo que ' \
           'ya se le mandó ni presiones; termina con UNA sola pregunta fácil de contestar.'

  LAST_URGENCY = 'Es el ÚLTIMO mensaje: si hay una urgencia REAL en LA FICHA (la fecha del evento, el cupo, la vigencia) ' \
                 'dila; nunca inventes urgencia. Dale una salida fácil («¿te lo aparto o lo dejamos para otra ocasión?»)'

  # Por tipo: [primer mensaje, toque 1, de en medio, el último].
  ANGLES = {
    'offer' => ['Es el primer mensaje: corto, sin ligas ni la información completa; termina preguntando si le gustaría conocer más.',
                'Recordatorio: retoma lo que se le mandó y destaca UN beneficio concreto de LA FICHA (precio, ahorro, lo que incluye)',
                'Otro ángulo: adelántate a la duda u objeción más común (de las preguntas autorizadas) o usa lo de este contacto',
                LAST_URGENCY],
    'invite' => ['Es el primer mensaje: corto, sin ligas ni la información completa; termina preguntando si le gustaría que le cuentes.',
                 'Recordatorio: retoma la invitación y destaca UN beneficio concreto del evento (qué va a ver, para qué le sirve)',
                 'Otro ángulo: adelántate a la duda más común (costo, duración, si se graba) de las preguntas autorizadas',
                 LAST_URGENCY],
    'reactivate' => ['Es el primer mensaje: salúdalo como cliente de antes (menciona lo que compró si lo sabes), corto, y pregúntale ' \
                     'si le interesa lo que tienes para que vuelva.',
                     'Recordatorio: conecta lo que compró antes con UN beneficio concreto de la oferta para volver',
                     'Otro ángulo: pregúntale con interés genuino si algo cambió o qué necesita ahora, y adelántate a la objeción más común',
                     LAST_URGENCY],
    'renew' => ['Es el primer mensaje: recuérdale qué le vence y cuándo (sus datos), corto, y pregúntale si le ayudas a renovarlo o pagarlo.',
                'Recordatorio: dile qué le vence y la fecha, y lo fácil que es hacerlo (cómo se paga, según LA FICHA)',
                'Otro ángulo: adelántate a la duda más común (cuánto es, cómo pagar, qué pasa si se vence) con sus datos',
                'Es el ÚLTIMO recordatorio antes de que venza: di la fecha real y qué pasa si se vence (solo si está en LA FICHA); ' \
                'ofrécele ayuda para hacerlo ya'],
    'survey' => ['Es el primer mensaje: invítalo a contestar unas preguntas sobre su servicio (es un minuto y su opinión sirve para ' \
                 'mejorar); todavía no hagas la primera pregunta.',
                 'Recordatorio: es un minuto y su opinión cuenta; pregúntale si te la regala',
                 'Otro ángulo: para facilitarle, hazle directamente la PRIMERA pregunta de la encuesta',
                 'Es el ÚLTIMO mensaje: agradécele de todos modos y déjale la puerta abierta para contestar cuando pueda']
  }.freeze

  # touch: el número de mensaje (1 = el primero); total: cuántos salen.
  # how: { kind: 'offer', clicked: false, email: false (correo: más largo y con la liga), link: '' }
  def note(touch, total, how = {})
    link = how[:link].to_s
    return "Ya dio clic en la liga pero no ha contestado: pregúntale en corto si pudo hacerlo y ofrécele ayuda#{link}. #{ALWAYS}" if how[:clicked]

    "No ha contestado. #{angle(touch, total, how[:kind])}#{link} #{length(how[:email])} #{ALWAYS}"
  end

  # El primer mensaje con la ventana abierta (WhatsApp), según el tipo.
  def first(kind) = angles(kind)[0]

  def angle(touch, total, kind = 'offer')
    list = angles(kind)
    return list[3] if touch >= total
    return list[1] if touch == 2

    list[2]
  end

  def angles(kind) = ANGLES.fetch(kind.to_s, ANGLES['offer'])

  def length(email) = email ? 'Más corto que el anterior: 1 o 2 párrafos.' : 'Muy corto: 1 o 2 renglones, 1 emoji como mucho.'
end
