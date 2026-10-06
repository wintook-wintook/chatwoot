# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — UN TURNO CON @solicitudes (pieza 5, 26/09/2026)
# ================================================================================
# El mensaje cae en una ruta con @solicitudes:
#   Extractor (servicios) → Registry (un caso por servicio, reiteraciones) → respuesta con todos,
#   numerados por conversación (1️⃣ 2️⃣ 3️⃣), y UNA pregunta con lo que falta de cada uno.
# F3 agrega los horarios de cada servicio. Plan: docs/solicitudes_multiservicio_plan.md §4
#
# nil = el mensaje no pide servicios (saludo, pregunta): el motor sigue como siempre.
# ================================================================================

class ContactTrackings::ServiceRequests::Turn
  DIRECTIVE_RE = /@solicitudes\b/i
  NUMBERS = %w[0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟].freeze
  DAYS = %w[dom lun mar mié jue vie sáb].freeze
  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

  def self.route?(escalation)
    escalation.to_s.match?(DIRECTIVE_RE)
  end

  # Número del servicio para el cliente: su lugar entre los abiertos de la conversación.
  def self.number(ticket, conversation)
    lugar = ContactTrackings::ServiceRequests::Registry.open_cases(conversation).pluck(:id).index(ticket.id)
    lugar ? NUMBERS.fetch(lugar + 1, "#{lugar + 1}.") : '•'
  end

  # Una renta (F7): «1A 1 nov 2026 → 30 abr 2027 (GR-90)», del primero al último día.
  def self.period_text(oferta, timezone)
    inicio = Time.zone.parse(oferta['slot']).in_time_zone(timezone).to_date
    fin = Time.zone.parse(oferta['end_time']).in_time_zone(timezone).to_date - 1
    "#{inicio.day} #{MONTHS[inicio.month - 1]} #{inicio.year} → #{fin.day} #{MONTHS[fin.month - 1]} #{fin.year}"
  end

  def initialize(tracking:, message:, branch:, timezone:, context: nil)
    @tracking = tracking
    @message = message
    @branch = branch
    @timezone = timezone
    @context = context
  end

  def call
    servicios = ContactTrackings::ServiceRequests::Extractor.new(
      account: @message.account, text: text, tracking: @tracking, context: @context, open_cases: open_cases_text
    ).call
    return nil if servicios.nil?
    return complete_pending if servicios.empty?

    entries = registry.register!(servicios)
    reply(entries, plans(entries))
  end

  # Observaciones SSUSA 2 y 5: el bot pidió datos o la hora y el cliente contesta solo eso
  # («es escombro, 14 t», «a las 10»). Se completan los casos que esperaban algo; si el mensaje
  # no les agregó nada, no es para ellos y el motor sigue como siempre.
  def complete_pending
    entries = waiting_cases.filter_map do |caso|
      antes = [caso.metadata.deep_dup, caso.custom_attributes.deep_dup]
      entry = registry.complete!(caso)
      entry unless [caso.metadata.except(ContactTrackings::ServiceRequests::Fields::PENDING_KEY), caso.custom_attributes] ==
                   [antes.first.except(ContactTrackings::ServiceRequests::Fields::PENDING_KEY), antes.last]
    end
    return nil if entries.empty?

    reply(entries, plans(entries))
  end

  private

  # «1. Hiab 14 a 15 t · KM10.5 Prefabricado · sáb 3 oct · carga escombro · 14.0 t (caso 01126)» — mismo
  # número que ve el cliente, para que la IA diga cuál corrige (observación SSUSA 9).
  def open_cases_text
    ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).each_with_index.map do |caso, i|
      datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
      partes = [datos['label'].presence || caso.title, route(datos), when_text(datos),
                datos['cargo'] && "carga #{datos['cargo']}", datos['weight_t'] && "#{datos['weight_t']} t"]
      "#{i + 1}. #{partes.compact_blank.join(' · ')} (caso #{caso.folio.presence || caso.id})"
    end
  end

  def text
    @text ||= ContactTrackings::AttachmentText.message_text(@message) # pieza 7: y sus adjuntos
  end

  def registry
    @registry ||= ContactTrackings::ServiceRequests::Registry.new(
      tracking: @tracking, message: @message, escalation: @branch&.escalation, timezone: @timezone, text: text
    )
  end

  # Sin tarea todavía y con algo pendiente: un campo obligatorio, la fecha o la hora.
  def waiting_cases
    ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).select do |caso|
      datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
      caso.metadata['meeting_id'].blank? && caso.metadata['oferta'].blank? &&
        (Array(caso.metadata[ContactTrackings::ServiceRequests::Fields::PENDING_KEY]).any? || datos['date'].blank? || datos['time'].blank?)
    end
  end

  # F3: con @agendar_calendar en la ruta, las opciones de horario de cada servicio.
  def plans(entries)
    agenda = ContactTrackings::ServiceRequests::Scheduler.new(tracking: @tracking, route: @branch, timezone: @timezone)
    return {} unless agenda.agenda?

    # Un servicio que ya tiene su tarea (apartado, esperando pago, confirmado) no se vuelve a
    # ofrecer al reiterarlo: su línea dice en qué estado está.
    entries.reject { |entry| entry.ticket.metadata['meeting_id'].present? }
           .to_h { |entry| [entry.ticket.id, hold_if_exact(agenda.plan(entry.ticket, position(entry.ticket)))] }
  end

  # Observación SSUSA 5: pidió una hora y está libre → se aparta directo (tentativo si la ruta
  # dice modo=tentativo), sin hacerle elegir de una lista.
  def hold_if_exact(plan)
    return plan unless plan.exact && plan.offers.one?

    ContactTrackings::ServiceRequests::Choice.new(tracking: @tracking, message: @message, timezone: @timezone,
                                                  tentative: tentative?).hold(plan.ticket, plan.offers.first)
    plan.held = plan.offers.first
    plan.offers = []
    plan
  end

  def tentative?
    ContactTrackings::CalendarOptions.parse(@branch&.escalation)&.tentative || false
  end

  def position(ticket)
    ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).pluck(:id).index(ticket.id).to_i + 1
  end

  def reply(entries, planes)
    lineas = entries.map do |entry|
      plan = planes[entry.ticket.id]
      [line(entry), units_lines(plan), options_line(plan)].compact.join("\n")
    end
    faltan = entries.filter_map { |entry| missing(entry, planes[entry.ticket.id]) }
    "#{header(entries)}\n\n#{lineas.join("\n")}\n\n#{closing(faltan, planes)}"
  end

  def closing(faltan, planes)
    partes = []
    partes << "Para programarlos me falta: #{faltan.join('; ')}." if faltan.any?
    partes.concat(schedule_hints(planes.values))
    partes << 'Un asesor revisa la disponibilidad y te confirma.' if partes.empty?
    partes.join("\n")
  end

  def schedule_hints(planes)
    pistas = []
    if planes.any? { |plan| plan.offers.present? }
      pistas << 'Responde con los horarios que quieres apartar (por ejemplo «1A y 3B»), o «sí» para la primera opción de cada uno.'
    end
    pistas << 'Queda apartado; cuando me confirmes el servicio lo dejo en firme.' if planes.any?(&:held) && tentative?
    pistas
  end

  # Observación SSUSA 4: antes del horario, qué unidad es («🚛 TP-64: Low boy · Peso max t: 60»),
  # para que el cliente vea si le sirve. Las columnas las elige la ruta (ver Scheduler).
  def units_lines(plan)
    return nil if plan.nil? || plan.units.blank?

    nombres = (plan.offers + [plan.held].compact).to_h { |oferta| [oferta['gcal'], oferta['calendar_name']] }
    plan.units.map { |gcal, descripcion| "    🚛 #{nombres[gcal] || 'Unidad'}: #{descripcion}" }.join("\n")
  end

  # «   a las 08:00 no hay; lo que sí hay → 1A 09:00–10:00 (TP-64) · 1B …», o lo que se apartó.
  def options_line(plan)
    return nil if plan.nil?
    return "    ✅ #{plan.note.capitalize}: #{held_text(plan.held)}" if plan.held
    return nil if plan.offers.empty? && plan.note.nil?

    opciones = plan.offers.map { |oferta| option_text(oferta, plan.requested) }
    "    #{[plan.note, opciones.join(' · ').presence].compact.join(' → ')}"
  end

  def held_text(oferta)
    inicio = Time.zone.parse(oferta['slot']).in_time_zone(@timezone)
    fin = Time.zone.parse(oferta['end_time']).in_time_zone(@timezone)
    "#{tentative? ? 'te lo aparté' : 'te lo agendé'} de #{inicio.strftime('%H:%M')} a #{fin.strftime('%H:%M')} (#{oferta['calendar_name']})"
  end

  def option_text(oferta, pedido)
    return "#{oferta['code']} #{self.class.period_text(oferta, @timezone)} (#{oferta['calendar_name']})" if oferta['all_day']

    inicio = Time.zone.parse(oferta['slot']).in_time_zone(@timezone)
    fin = Time.zone.parse(oferta['end_time']).in_time_zone(@timezone)
    dia = pedido && inicio.to_date == pedido.to_date ? '' : "#{DAYS[inicio.wday]} #{inicio.day} #{MONTHS[inicio.month - 1]} "
    "#{oferta['code']} #{dia}#{inicio.strftime('%H:%M')}–#{fin.strftime('%H:%M')} (#{oferta['calendar_name']})"
  end

  def header(entries)
    nuevos = entries.count(&:created)
    return "Recibí #{entries.size == 1 ? '1 servicio' : "#{entries.size} servicios"}:" if nuevos == entries.size

    "Actualicé #{entries.size - nuevos == 1 ? '1 servicio' : "#{entries.size - nuevos} servicios"} que ya tenía" \
      "#{nuevos.positive? ? " y agregué #{nuevos}" : ''}:"
  end

  STATES = { 'apartado' => '📌 apartado', 'esperando_pago' => '💳 esperando pago', 'confirmado' => '✅ confirmado' }.freeze

  def line(entry)
    datos = entry.ticket.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY]
    partes = [datos['label'].presence || 'Servicio', route(datos), when_text(datos),
              STATES[entry.ticket.metadata['estado']]].compact_blank
    "#{self.class.number(entry.ticket, @message.conversation)} #{partes.join(' · ')} (caso #{entry.ticket.folio.presence || entry.ticket.id})"
  end

  def route(datos)
    paradas = Array(datos['stops']).pluck('lugar')
    paradas.size > 1 ? "#{paradas.first} → #{paradas.last}" : paradas.first
  end

  def when_text(datos)
    return nil if datos['date'].blank?

    fecha = Date.iso8601(datos['date'])
    "#{DAYS[fecha.wday]} #{fecha.day} #{MONTHS[fecha.month - 1]}#{" #{datos['time']}" if datos['time']}"
  end

  # Sin fecha no se puede programar; una renta sin fecha de inicio igual. Lo demás que se pide:
  #   · con campos en el tipo de caso → sus OBLIGATORIOS vacíos (observación SSUSA 2)
  #   · sin campos → dónde es (como antes)
  #   · con fecha y sin hora → la hora (observación SSUSA 5: no se lista la agenda entera)
  def missing(entry, plan = nil)
    faltan = ContactTrackings::ServiceRequests::Fields.missing_labels(entry.ticket) + basic_missing(entry.ticket)
    faltan << 'a qué hora lo necesitas' if plan&.need_time
    return nil if faltan.empty?

    # Con comas: las etiquetas de los campos ya traen «y» («Material a transportar y cantidad»).
    "del #{self.class.number(entry.ticket, @message.conversation)} #{faltan.join(', ')}"
  end

  def basic_missing(caso)
    datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY]
    faltan = []
    faltan << 'la fecha' if datos['date'].blank? && !ContactTrackings::ServiceRequests::Fields.date_field_missing?(caso)
    faltan << 'dónde es' if Array(datos['stops']).empty? && caso.case_type&.case_type_fields.blank?
    faltan
  end
end
