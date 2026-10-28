# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — UN TURNO CON @solicitudes (pieza 5, 26/09/2026)
# ================================================================================
# El mensaje cae en una ruta con @solicitudes:
#   Extractor (servicios) → Registry (un caso por servicio, reiteraciones) → respuesta con todos,
#   numerados por conversación, un bloque por servicio (Block) con lo que falta dentro, y el cierre
#   una sola vez. F3 agrega los horarios de cada servicio. Plan: docs/solicitudes_multiservicio_plan.md §4
#   Formato: docs/solicitudes_mensaje_horarios_plan.md §3 (observaciones SSUSA 22/10).
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

  # El mensaje cayó en OTRA ruta (punto 9, conv. 396: «perdón, el destino es Comalcalco» se fue a
  # consulta_estado_caso). Solo se toman los servicios que la IA marcó como corrección de un caso
  # abierto (o lo que completa uno pendiente); nunca se abre uno nuevo desde otra ruta.
  def corrections_only = (@only_corrections = true) && call

  # Casos que ya existían, con horarios nuevos (OtherUnit: «¿tienes otra?»).
  def replan(entries) = reply(entries, plans(entries))

  def call
    return @resumen if (@resumen = ContactTrackings::ServiceRequests::Status.new(message: @message, timezone: @timezone).call)

    servicios = ContactTrackings::ServiceRequests::Extractor.new(
      account: @message.account, text: text, tracking: @tracking, context: @context, open_cases: open_cases_text
    ).call
    return nil if servicios.nil?

    servicios = servicios.select(&:case_ref) if @only_corrections
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

  # pieza 7: el texto del mensaje y sus adjuntos
  def text = (@text ||= ContactTrackings::AttachmentText.message_text(@message))

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
  # Lo relacionado (no era lo que pidió, observación SSUSA 1) solo se recomienda: lo confirma él.
  def hold_if_exact(plan)
    return plan unless plan.exact && plan.offers.one? && plan.related.blank?

    ContactTrackings::ServiceRequests::Choice.new(tracking: @tracking, message: @message, timezone: @timezone,
                                                  tentative: tentative?).hold(plan.ticket, plan.offers.first)
    plan.held = plan.offers.first
    plan.offers = []
    plan
  end

  def tentative? = ContactTrackings::CalendarOptions.parse(@branch&.escalation)&.tentative || false

  def position(ticket)
    ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).pluck(:id).index(ticket.id).to_i + 1
  end

  # Observaciones SSUSA 22/10 (F3): un bloque por servicio (Block) y el cierre una sola vez.
  def reply(entries, planes)
    bloque = ContactTrackings::ServiceRequests::Block.new(conversation: @message.conversation, timezone: @timezone)
    faltan = entries.to_h { |entry| [entry.ticket.id, missing(entry, planes[entry.ticket.id])] }
    servicios = entries.map do |entry|
      bloque.service(entry.ticket, plan: planes[entry.ticket.id], missing: faltan[entry.ticket.id])
    end
    "#{header(entries)}\n\n#{servicios.join("\n\n")}\n\n#{closing(faltan.values.any?(&:present?), planes, entries)}"
  end

  def closing(faltan, planes, entries)
    partes = schedule_hints(planes.values)
    partes << MISSING_CLOSING if faltan && partes.empty?
    partes << fallback_closing(entries) if partes.empty?
    partes.join("\n")
  end

  # Todos ya apartados (una corrección, conv. 397): no se dice «un asesor revisa la disponibilidad».
  def fallback_closing(entries) = entries.all? { |e| e.ticket.metadata['meeting_id'].present? } ? HELD_CLOSING : ADVISOR_CLOSING
  HELD_CLOSING = 'Listo, quedó corregido y tu horario sigue apartado.'
  ADVISOR_CLOSING = 'Un asesor revisa la disponibilidad y te confirma.'
  MISSING_CLOSING = 'Cuando me pases lo que falta, lo programo.'

  def schedule_hints(planes)
    pistas = []
    ofertas = planes.flat_map { |plan| Array(plan.offers) }
    pistas << choose_hint(planes, ofertas) if ofertas.any?
    pistas << 'Queda apartado; cuando me confirmes el servicio lo dejo en firme.' if planes.any?(&:held) && tentative?
    pistas
  end

  # El ejemplo sale de lo ofrecido: una opción B real («la de las 14:00» o «1B»).
  def choose_hint(planes, ofertas)
    return 'Responde «sí» para apartarlo, o dime qué otra hora te acomoda.' if ofertas.one?

    otra = planes.find { |plan| Array(plan.offers).many? }&.offers&.second
    ejemplo = if otra && !otra['all_day']
                "«la de las #{Time.zone.parse(otra['slot']).in_time_zone(@timezone).strftime('%H:%M')}» o «#{otra['code']}»"
              else
                "«#{ofertas.last['code']}»"
              end
    "Responde «sí» para apartar la opción A de cada servicio, o dime cuál prefieres (por ejemplo #{ejemplo})."
  end

  # «Tu solicitud tiene 2 servicios:» si se muestran todos; si solo cambian algunos, cuáles.
  def header(entries)
    abiertos = ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).pluck(:id)
    total = abiertos.size
    return "Tu solicitud tiene #{total == 1 ? '1 servicio' : "#{total} servicios"}:" if (abiertos - entries.map { |e| e.ticket.id }).empty?

    numeros = entries.map { |entry| abiertos.index(entry.ticket.id).to_i + 1 }
    numeros.one? ? "Así quedó el servicio #{numeros.first}:" : "Así quedaron los servicios #{numeros[0..-2].join(', ')} y #{numeros.last}:"
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

    faltan
  end

  def basic_missing(caso)
    datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY]
    faltan = []
    faltan << 'la fecha' if datos['date'].blank? && !ContactTrackings::ServiceRequests::Fields.date_field_missing?(caso)
    faltan << 'dónde es' if Array(datos['stops']).empty? && caso.case_type&.case_type_fields.blank?
    faltan
  end
end
