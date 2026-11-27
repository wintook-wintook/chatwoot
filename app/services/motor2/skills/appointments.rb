# frozen_string_literal: true

# «Citas» — agendar, mover o cancelar las citas del cliente en las agendas de la ficha
# (tracking_templates.calendar_integration_ids, con Google conectado). Copia adaptada de
# ReadyAgents::Appointments (que no se toca), con lo que el 1.0 ya aprendió:
#   - los días de la semana los da el código (lecciones df8098b5 / 15668007: el modelo se equivoca);
#   - no se confirma si la cita no se creó (83ea3b9a); se revisa otra vez que el horario siga libre;
#   - moverla mueve el evento (29c38a2e); la cita se guarda estructurada en la memoria (ac88ccd6).
# Puede tener varias citas en la plática (otro servicio, otro día o para otra persona: Motor2::Skills::AppointmentList).
# El horario que elige de los ofrecidos («10», «el primero», «el de John») lo entiende el código (Motor2::SlotPick).
# Al agendar regresa lo que hay que confirmarle: día, hora, con quién, dónde y, en citas de servicio, total y duración.
# Sin agenda legible pasa a una persona con el motivo. En el chat de prueba lee horarios reales pero no crea nada.
#
#   skills.appointments = { 'on' => true, 'kind' => 'visita', 'location' => 'Av. Juárez 10', 'when' => 'quiere conocer el plantel' }
# Una función (§11.14) puede dar con quién y cuánto dura: 'user_ids' (personas con Google
# conectado; si no, las agendas de la ficha) y 'minutes'. Al agendar, la función hace lo suyo
# (Motor2::Outcomes#booked: en «Atención a prospectos», etiqueta, nota y a quién se asigna).
# Citas de servicio ('services' => true): Motor2::Skills::AppointmentServices.
#
#   memoria: state['appointments'] (AppointmentList), state['offered_slots'] (los últimos horarios que se le dieron)
class Motor2::Skills::Appointments < Motor2::Skills::Base
  include Motor2::Skills::AppointmentServices
  include Motor2::Skills::AppointmentList
  include Motor2::Skills::AppointmentChanges

  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
  KINDS = %w[llamada videollamada visita oficina].freeze
  OFFER = 3
  SYNC_WAIT = 30.seconds
  DATE = { type: 'string', description: 'YYYY-MM-DDTHH:MM' }.freeze
  WHICH = { type: 'string', description: 'Cuál cita (día, hora, servicio o para quién), si tiene varias' }.freeze
  FOR = { type: 'string', description: 'Para quién es, si no es para quien escribe (su nombre y quién es: «Laura, su esposa»)' }.freeze

  def self.key = 'appointments'

  def self.label(time) = "#{DAYS[time.wday]} #{time.day} de #{MONTHS[time.month - 1]}, #{time.strftime('%H:%M')}"

  def on? = super && integration_ids.any?

  def tools
    [fn('ver_horarios', 'Horarios libres para la cita (3). Sin «desde», los más próximos; con un día (YYYY-MM-DD) desde ' \
                        'ese día; con día y hora (YYYY-MM-DDTHH:MM) dice si ese horario exacto está libre.', { desde: STR }.merge(service_params)),
     fn('agendar_cita', 'Agenda la cita en el horario que el cliente eligió (uno que salió en ver_horarios).',
        { inicio: DATE, notas: STR, para: FOR }.merge(service_params), book_required),
     fn('mover_cita', 'Cambia una cita del cliente a otro horario libre.', { inicio: DATE, cita: WHICH }, %w[inicio]),
     fn('cancelar_cita', 'Cancela una cita del cliente.', { motivo: STR, cita: WHICH }, %w[motivo])]
  end

  def instructions
    <<~TEXT.strip
      - CITAS (#{kind}): ofrécela cuando #{setting(:when).presence || 'el cliente quiera avanzar o la pida'}. Los horarios salen
        solo de ver_horarios; si dice un día sin número («el lunes»), usa la fecha de la lista de días y confírmasela completa.
        Si le diste horarios y dice que sí sin escoger, pregúntale cuál. Solo di que quedó agendada si agendar_cita regresó ok
        y confírmale lo que regrese (día, hora, con quién, dónde#{', total y duración' if services?}); pídele avisar con
        tiempo si no puede llegar. Después de agendar puedes ofrecerle UNA vez si quiere algo más.
        Puede tener varias citas (otro día, otro servicio o para otra persona: pregúntale su nombre y pásalo en «para»; si la
        quiere a la misma hora que la suya, busca ese horario exacto).#{services_instructions}
    TEXT
  end

  def memory
    days = (0..7).map { |i| (now + i.days).then { |d| "#{DAYS[d.wday]} #{d.strftime('%Y-%m-%d')}" } }
    ["DÍAS: #{days.join(', ')}", booked_lines].compact.join("\n")
  end

  # Contestó con uno de los horarios que se le dieron: el código ya sabe cuál.
  def prepare(history)
    last = Array(history).last
    return unless last && last[:role].to_s == 'user'

    @picked = Motor2::SlotPick.call(last[:content], state['offered_slots'])
  end

  def turn_note
    return '' unless @picked

    services = Array(state['offered_services']).presence
    "ELIGIÓ EL HORARIO: #{@picked['texto']}#{" con #{@picked['con']}" if @picked['con']} (inicio #{@picked['inicio']}). Llama " \
      "agendar_cita con ese inicio#{" y con=#{@picked['con']}" if @picked['con']}#{" y los servicios #{services.join(', ')}" if services} " \
      '(o mover_cita si está cambiando una ' \
      'cita); no le vuelvas a dar horarios.'
  end

  def call(name, args)
    case name
    when 'ver_horarios' then before_slots(args) || slots(args['desde'])
    when 'agendar_cita' then before_slots(args) || book(args['inicio'], args['notas'], args['para'])
    when 'mover_cita' then move(args['inicio'], args['cita'])
    else cancel(args['motivo'], args['cita'])
    end
  end

  private

  # Los datos obligatorios del contacto (Atención a prospectos) van antes de la cita: después ya no los da.
  def missing_contact
    function = config.function
    return nil unless function.respond_to?(:missing_contact)

    missing = function.missing_contact(@turn.conversation&.contact, @turn.noted_contact)
    return unless missing.any?

    { error: "Antes de ofrecerle horarios pídele su #{missing.join(' y ')} (con naturalidad, en una pregunta) y guárdalo con " \
             'actualizar_contacto.' }
  end

  def integration_ids
    @integration_ids ||= begin
      scope = UserCalendarIntegration.where(account_id: config.account.id)
      users = Array(setting(:user_ids)).map(&:to_i).select(&:positive?)
      (users.any? ? scope.where(user_id: users) : scope.where(id: Array(config.template.calendar_integration_ids))).pluck(:id)
    end
  end

  def kind = setting(:kind).presence_in(KINDS) || 'llamada'

  def zone = config.zone

  def now = Time.current.in_time_zone(zone)

  def service
    @service ||= ContactTrackings::AvailabilitySlotService.new(calendar_integration_ids: integration_ids, timezone: zone.tzinfo.name,
                                                               slot_duration: minutes, working_hours: working_hours)
  end

  def working_hours
    inbox = @turn.conversation&.inbox || config.inbox
    inbox.working_hours if inbox&.working_hours_enabled?
  end

  def local(time) = self.class.label(time.in_time_zone(zone))

  def slots(from)
    exact = exact_slot(from)
    list = (exact ? [exact] : service.call(from: parse(from))).reject { |s| test_taken(s) }
    return none_free if list.empty?

    rows = list.first(OFFER).map { |s| slot_row(s) }
    offered!(rows)
    sourced({ horarios: rows, duracion_minutos: minutes, servicios: services_detail, total: services_total,
              nota: exact ? 'Ese horario está libre.' : nil }.compact)
  end

  # Precios, total y duración salieron de la herramienta: se pueden decir (Motor2::Runner#unsourced?, AreaChecks).
  def sourced(result)
    @turn.seen << result.to_json
    @turn.evidence << "Citas: #{result.to_json}"
    result
  end

  # Los que se le dieron: si contesta «10» o «el primero», el código sabe cuál (Motor2::SlotPick).
  def offered!(rows)
    state['offered_slots'] = rows.map { |r| r.transform_keys(&:to_s) }
    state['offered_services'] = chosen_names
  end

  # Con día y hora, si ese horario exacto está libre.
  def exact_slot(from)
    start = parse(from)
    start && from.to_s.include?('T') ? service.slot_for(start) : nil
  end

  def book(from, notes, for_whom)
    slot = free_slot(from)
    return slot if slot[:error]

    @for_whom = for_whom.to_s.squish.first(80).presence
    return test_taken(slot) || test_booking(slot) if test?

    created = create_meeting(slot, notes)
    after_booking(created)
    confirmation(created.starts_at, created.organizer&.name, created.ends_at - created.starts_at)
  end

  # Después de mandar el mensaje: los archivos de la cita, la nota y etiqueta, y el recordatorio.
  def after_booking(created)
    trace.event(:cita, local(created.starts_at))
    # Campaña: los archivos de «Al agendar o comprar» (mapa de la sucursal, qué traer) van con este mensaje.
    Motor2::Skills::Files.attach_unsent(@turn, config, state, 'confirm') if config.function.respond_to?(:reply_text)
    @turn.after_send { booked_files }
    @turn.after_send { Motor2::Outcomes.new(@turn.tracking, @turn.conversation, config).booked(created) }
    notice(created)
  end

  def parse(value)
    return nil if value.blank?

    value.to_s.include?('T') ? zone.parse(value.to_s) : zone.parse("#{value} 00:00")
  rescue ArgumentError
    nil
  end

  def free_slot(from)
    start = parse(from)
    return { error: 'Fecha no válida; usa YYYY-MM-DDTHH:MM.' } unless start && from.to_s.include?('T')

    service.slot_for(start) || (service.calendars_unreadable? ? no_calendar : taken(start))
  end

  def none_free
    return no_calendar if service.calendars_unreadable?

    { horarios: [], nota: 'No hay horarios libres en los próximos días: ofrécele pasarlo con el equipo.' }
  end

  def taken(start)
    others = service.call(from: start.beginning_of_day).reject { |s| s[:slot] == start }.first(OFFER)
    rows = others.map { |s| slot_row(s) }
    offered!(rows)
    { error: 'Ese horario se acaba de ocupar.', horarios: rows, nota: 'Dile que ese horario se acaba de ocupar y ofrécele estos.' }
  end

  # No se pudo leer la agenda: no es que esté ocupado. Se pasa a una persona con el motivo.
  def no_calendar
    who = service.unreadable_users.to_sentence.presence || 'quien agenda'
    @turn.decide('handoff', "No se pudo leer el calendario de #{who}: reconéctalo en Agenda › Calendario y agenda la cita a mano.")
    { error: 'No pude revisar la agenda.',
      nota: 'No le digas que está ocupado ni ofrezcas horarios: dile que en un momento alguien del equipo le confirma.' }
  end

  def slot_row(slot)
    at = slot[:slot].in_time_zone(zone)
    { inicio: at.strftime('%Y-%m-%dT%H:%M'), texto: self.class.label(at), con: slot[:agent_name] }
  end

  def create_meeting(slot, notes)
    organizer = UserCalendarIntegration.find(slot[:calendar_integration_id]).user
    contact = @turn.conversation.contact
    created = AgendaItems::Creator.new(account: config.account, user: organizer, organizer: organizer,
                                       client: { contact: contact, organization: contact&.organization },
                                       attrs: meeting_attrs(slot, notes, contact)).call
    remember('meeting_id' => created.id, 'services' => chosen_names, 'for' => @for_whom)
    created
  end

  def meeting_attrs(slot, notes, contact)
    data = state.data.map { |k, v| "• #{k}: #{v}" }.join("\n")
    { title: meeting_title(contact).first(255), description: [notes, data].compact_blank.join("\n"),
      starts_at: slot[:slot], ends_at: slot[:end_time], location: setting(:location).presence,
      is_visit: kind == 'visita', attendee_emails: [contact&.email].compact_blank }
  end

  def booked_files
    ContactTrackings::EventFiles.send_for(@turn.tracking, :booking, conversation: @turn.conversation,
                                                                    sender: Motor2::Delivery.sender(config.account))
  end
end
