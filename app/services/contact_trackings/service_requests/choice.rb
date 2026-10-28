# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — EL CLIENTE ELIGE HORARIOS (pieza 5, F3, 26/09/2026)
# ================================================================================
# Con opciones ofrecidas (metadata['oferta'] de cada caso-servicio):
#   «1A y 3B»            → esas
#   «sí» / «apártalos»   → la primera opción de cada servicio con oferta
#   lo demás             → lo lee la IA (Interpreter, observaciones SSUSA 22/10): «adelante»,
#                          «la de las 14», «el 2 a las 16»; si no se sabe cuál, una pregunta;
#                          «ninguna» → pide otro día u hora. Sin IA quedan los patrones.
# Apartado y sin datos pendientes, con @confirmar_servicio en el agente: «¿Confirmo el
# servicio?»; el «sí» siguiente lo confirma con Actions aunque el router no elija esa ruta.
# Cada una se aparta como Tarea agendada en el calendario de SU equipo (ServiceMeeting);
# con @agendar_calendar(modo=tentativo) queda «[TENTATIVO]», si no, en firme.
# nil = no hay ofertas abiertas o el mensaje no elige nada: el motor sigue.
# ================================================================================

class ContactTrackings::ServiceRequests::Choice
  # «1A», «1a», «1 A»; con espacio solo mayúscula: «el 2 a las 16» no es «2A».
  CODE_RE = /\b(\d{1,2})(?:([aAbBcC])|\s+([ABC]))\b/
  YES_RE = /\A\W*(s[ií]|ok|va|vale|claro|dale|de acuerdo|ap[aá]rta\w*|todos?|perfecto|adelante|confirm\w*|listo|sale|
               [oó]rale|est[aá]\s+bien|me\s+parece|correcto|excelente)\b/ix
  ASKED_KEY = 'confirmar_pendiente'
  REJECT_TEXT = 'Entendido. ¿Qué otro día u hora te acomoda? Te busco horarios para entonces.'
  # «sí pero más tarde» con una sola opción: no hay entre qué escoger (conv. 653).
  OTHER_TIME_TEXT = '¿A qué hora te acomoda? Te busco horario para entonces.'
  Pick = ContactTrackings::ServiceRequests::Interpreter::Result

  def initialize(tracking:, message:, timezone:, tentative:)
    @tracking = tracking
    @message = message
    @timezone = timezone
    @tentative = tentative
  end

  def call
    abiertos = ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).to_a
    con_oferta = abiertos.select { |caso| caso.metadata['oferta'].present? }
    return confirm_asked(abiertos) if con_oferta.empty?

    respuesta = read(abiertos, con_oferta)
    case respuesta.action
    when :elegir then answer(abiertos, con_oferta, respuesta)
    when :ambigua then question(con_oferta)
    when :rechazo then REJECT_TEXT
    end
  end

  # Aparta UNA opción. Público para Turn: con la hora pedida libre se aparta sin preguntar
  # (observación SSUSA 5). Devuelve [caso, tarea, oferta].
  def hold(caso, oferta)
    cancel_previous(caso) # al mover (F4): la tarea anterior se cancela al apartar la nueva
    slot = { slot: Time.zone.parse(oferta['slot']), end_time: Time.zone.parse(oferta['end_time']),
             calendar_integration_id: oferta['cal_id'], google_calendar_id: oferta['gcal'], all_day: oferta['all_day'] }
    tarea = ContactTrackings::ServiceMeeting.hold!(ticket: caso, slot: slot, title: caso.title, timezone: @timezone)
    ContactTrackings::ServiceMeeting.new(tarea).confirm! unless @tentative
    estado = { 'meeting_id' => tarea.id, 'estado' => @tentative ? 'apartado' : 'confirmado' }
    caso.update!(metadata: caso.metadata.except('oferta', ASKED_KEY).merge(estado), custom_attributes: assigned_unit(caso, oferta))
    [caso, tarea.reload, oferta]
  end

  private

  # Códigos escritos → esos (sin IA). Si no, la IA; sin IA, el «sí» de los patrones.
  def read(abiertos, con_oferta)
    texto = @message.content.to_s
    codigos = texto.scan(CODE_RE).map { |num, letra, mayuscula| "#{num}#{letra || mayuscula}".upcase }
    return Pick.new(action: :elegir, general: false, codes: codigos) if codigos.any?

    interpreter(abiertos, con_oferta).call ||
      Pick.new(action: texto.match?(YES_RE) ? :elegir : :otra, general: true, codes: [])
  end

  def interpreter(abiertos, con_oferta)
    numerados = con_oferta.map { |caso| [abiertos.index(caso) + 1, caso] }
    ContactTrackings::ServiceRequests::Interpreter.new(account: @message.account, text: @message.content, cases: numerados,
                                                       timezone: @timezone, tracking: @tracking)
  end

  def answer(abiertos, con_oferta, respuesta)
    elegidos = picks(abiertos, con_oferta, respuesta)
    return question(con_oferta) if elegidos.empty?

    # Antes de apartar: al apartar, la oferta sale del caso.
    @first_of_each = respuesta.general && con_oferta.any? { |caso| caso.metadata['oferta'].many? }
    apply(elegidos, con_oferta)
  end

  def picks(abiertos, con_oferta, respuesta)
    return con_oferta.map { |caso| [caso, caso.metadata['oferta'].first] } if respuesta.general

    respuesta.codes.filter_map { |codigo| pick(abiertos[codigo.to_i - 1], codigo) }.uniq { |caso, _| caso.id }
  end

  # «sí pero más tarde», «el otro»: una sola pregunta con las opciones de cada servicio, en su bloque.
  def question(con_oferta)
    return OTHER_TIME_TEXT if con_oferta.all? { |caso| caso.metadata['oferta'].one? }

    bloques = con_oferta.map do |caso|
      ofertas = caso.metadata['oferta']
      plan = ContactTrackings::ServiceRequests::Scheduler::Plan.new(ticket: caso, offers: ofertas,
                                                                    requested: Time.zone.parse(ofertas.first['slot']))
      block.service(caso, plan: plan)
    end
    "¿Cuál horario prefieres?\n\n#{bloques.join("\n\n")}\n\nDime la letra o la hora, por ejemplo #{example(con_oferta)}."
  end

  def example(con_oferta)
    oferta = con_oferta.first.metadata['oferta'].last
    return "«#{oferta['code']}»" if oferta['all_day']

    "«#{oferta['code']}» o «la de las #{Time.zone.parse(oferta['slot']).in_time_zone(@timezone).strftime('%H:%M')}»"
  end

  def block
    @block ||= ContactTrackings::ServiceRequests::Block.new(conversation: @message.conversation, timezone: @timezone)
  end

  # El «sí» a «¿Confirmo el servicio?»: lo confirma Actions con la ruta de @confirmar_servicio.
  def confirm_asked(abiertos)
    preguntados = abiertos.select { |caso| caso.metadata[ASKED_KEY] && caso.metadata['estado'] == 'apartado' }
    return nil if preguntados.empty? || !@message.content.to_s.match?(YES_RE) || confirm_route.nil?

    ContactTrackings::ServiceRequests::Actions.new(tracking: @tracking, message: @message, branch: confirm_route,
                                                   timezone: @timezone).call
  end

  def confirm_route
    return @confirm_route if defined?(@confirm_route)

    rutas = @tracking ? ContactTrackings::RouteMap.parse(@tracking.complementary_prompt.to_s).routes : []
    @confirm_route = rutas.find { |ruta| ruta.escalation.to_s.match?(ContactTrackings::ServiceConfirmation::DIRECTIVE_RE) }
  end

  def pick(caso, codigo)
    oferta = caso&.metadata&.dig('oferta')&.find { |o| o['code'].casecmp?(codigo) }
    oferta && [caso, oferta]
  end

  # @solicitudes(asignar=unidad): la unidad apartada (TP-111) va a ese campo del caso.
  def assigned_unit(caso, oferta)
    clave = caso.metadata[ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY]
    atributos = caso.custom_attributes.to_h
    clave.present? && oferta['calendar_name'].present? ? atributos.merge(clave => oferta['calendar_name']) : atributos
  end

  def apply(elegidos, con_oferta)
    libres, chocan = elegidos.partition { |caso, oferta| free?(caso, oferta) }
    apartados = libres.map { |caso, oferta| hold(caso, oferta) }
    reply(apartados, con_oferta.reject { |caso| libres.any? { |e| e.first.id == caso.id } }, chocan)
  end

  # Conv. 398: con un «sí» se apartaron dos servicios en la misma unidad a la misma hora. Se revisa
  # contra lo ya apartado en la conversación, incluido lo de este mismo mensaje.
  def free?(caso, oferta)
    !ContactTrackings::ServiceRequests::Taken.new(caso, offers: false)
                                             .busy?(oferta['gcal'], Time.zone.parse(oferta['slot']), Time.zone.parse(oferta['end_time']))
  end

  def cancel_previous(caso)
    anterior = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    ContactTrackings::ServiceMeeting.new(anterior).cancel! if anterior && !anterior.cancelled?
  end

  def reply(apartados, pendientes, chocan = [])
    partes = held_parts(apartados)
    partes << clash_text(chocan) if chocan.any?
    partes << "Falta elegir horario #{services_text(pendientes)}." if pendientes.any?
    partes.join("\n\n")
  end

  def held_parts(apartados)
    return [] if apartados.empty?

    bloques = apartados.map { |caso, tarea, oferta| block.service(caso, held: held_slot(tarea, oferta), sync_failed: tarea.sync_failed?) }
    partes = ["#{held_title(apartados)}\n\n#{bloques.join("\n\n")}"]
    partes << confirm_text(apartados.map(&:first)) if @tentative
    partes
  end

  def held_title(apartados)
    return 'Aparté la opción A de cada servicio:' if @first_of_each && @tentative
    return (apartados.one? ? 'Listo, aparté tu horario:' : 'Listo, aparté tus horarios:') if @tentative

    apartados.one? ? 'Listo, quedó agendado:' : 'Listo, quedaron agendados:'
  end

  # El horario real de la tarea (una renta conserva su periodo de la oferta).
  def held_slot(tarea, oferta)
    return oferta if oferta['all_day']

    oferta.merge('slot' => tarea.starts_at.iso8601, 'end_time' => tarea.ends_at.iso8601)
  end

  # Con todos los datos y @confirmar_servicio en el agente, se pregunta en el mismo mensaje.
  def confirm_text(casos)
    completos = casos.none? { |caso| Array(caso.metadata[ContactTrackings::ServiceRequests::Fields::PENDING_KEY]).any? }
    return 'Quedan pendientes de confirmar: cuando me confirmes el servicio, los dejo en firme.' unless completos && confirm_route

    casos.each { |caso| caso.update!(metadata: caso.metadata.merge(ASKED_KEY => true)) }
    casos.one? ? '¿Confirmo el servicio?' : '¿Confirmo los servicios?'
  end

  def clash_text(chocan)
    codigos = chocan.map { |_, oferta| oferta['code'] }.join(', ')
    "La opción #{codigos} ya no está libre: esa unidad la tiene otro de tus servicios a esa hora. Elige otra opción o dime otra hora."
  end

  # «del servicio 3», «de los servicios 2 y 3»
  def services_text(casos)
    numeros = casos.map { |caso| block.number(caso) }
    numeros.one? ? "del servicio #{numeros.first}" : "de los servicios #{numeros[0..-2].join(', ')} y #{numeros.last}"
  end
end
