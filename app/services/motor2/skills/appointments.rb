# frozen_string_literal: true

# «Citas» — agendar, mover o cancelar la cita del cliente en las agendas de la ficha
# (tracking_templates.calendar_integration_ids, con Google conectado). Copia adaptada de
# ReadyAgents::Appointments (que no se toca), con lo que el 1.0 ya aprendió:
#   - los días de la semana los da el código (lecciones df8098b5 / 15668007: el modelo se equivoca);
#   - no se confirma si la cita no se creó (83ea3b9a); se revisa otra vez que el horario siga libre;
#   - con cita agendada no vuelve a ofrecer horarios (be6c32cb); moverla mueve el evento (29c38a2e);
#   - la cita se guarda estructurada en la memoria, no como texto en el prompt (ac88ccd6).
# Sin agenda legible pasa a una persona con el motivo. En el chat de prueba lee horarios reales
# pero no crea nada.
#
#   skills.appointments = { 'on' => true, 'kind' => 'visita', 'location' => 'Av. Juárez 10', 'when' => 'quiere conocer el plantel' }
# Una función (§11.14) puede dar con quién y cuánto dura: 'user_ids' (personas con Google
# conectado; si no, las agendas de la ficha) y 'minutes'. Al agendar, la función hace lo suyo
# (Motor2::Outcomes#booked: en «Atención a prospectos», etiqueta, nota y a quién se asigna).
class Motor2::Skills::Appointments < Motor2::Skills::Base
  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
  KINDS = %w[llamada videollamada visita oficina].freeze
  OFFER = 3
  DATE = { type: 'string', description: 'YYYY-MM-DDTHH:MM' }.freeze

  def self.key = 'appointments'

  def self.label(time) = "#{DAYS[time.wday]} #{time.day} de #{MONTHS[time.month - 1]}, #{time.strftime('%H:%M')}"

  def on? = super && integration_ids.any?

  def tools
    [fn('ver_horarios', 'Horarios libres para la cita (3). Sin «desde», los más próximos; con un día (YYYY-MM-DD) desde ' \
                        'ese día; con día y hora (YYYY-MM-DDTHH:MM) dice si ese horario exacto está libre.', { desde: STR }),
     fn('agendar_cita', 'Agenda la cita en el horario que el cliente eligió (uno que salió en ver_horarios).',
        { inicio: DATE, notas: STR }, %w[inicio]),
     fn('mover_cita', 'Cambia la cita del cliente a otro horario libre.', { inicio: DATE }, %w[inicio]),
     fn('cancelar_cita', 'Cancela la cita del cliente.', { motivo: STR }, %w[motivo])]
  end

  def instructions
    <<~TEXT.strip
      - CITAS (#{kind}): ofrécela cuando #{setting(:when).presence || 'el cliente quiera avanzar o la pida'}. Los horarios salen
        solo de ver_horarios; si dice un día sin número («el lunes»), usa la fecha de la lista de días y confírmasela completa.
        Solo di que quedó agendada si agendar_cita regresó ok.
    TEXT
  end

  def memory
    days = (0..7).map { |i| (now + i.days).then { |d| "#{DAYS[d.wday]} #{d.strftime('%Y-%m-%d')}" } }
    lines = ["DÍAS: #{days.join(', ')}"]
    lines << "CITA AGENDADA: #{local(meeting.starts_at)} (no ofrezcas otra; puedes moverla o cancelarla)" if meeting&.scheduled?
    lines.join("\n")
  end

  def call(name, args)
    case name
    when 'ver_horarios' then missing_contact || slots(args['desde'])
    when 'agendar_cita' then missing_contact || book(args['inicio'], args['notas'])
    when 'mover_cita' then move(args['inicio'])
    else cancel(args['motivo'])
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

  def minutes = (setting(:minutes).presence || config.template.calendar_event_duration).to_i.clamp(15, 240)

  def zone = config.zone

  def now = Time.current.in_time_zone(zone)

  def meeting
    return @meeting if defined?(@meeting)

    @meeting = state.dig('appointment', 'meeting_id') && CaseMeeting.find_by(id: state.dig('appointment', 'meeting_id'))
  end

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
    return { nota: 'Ya tiene cita agendada: no ofrezcas otra; si quiere cambiarla usa mover_cita.' } if meeting&.scheduled?

    exact = exact_slot(from)
    list = exact ? [exact] : service.call(from: parse(from))
    return none_free if list.empty?

    { horarios: list.first(OFFER).map { |s| slot_row(s) }, duracion_minutos: minutes, nota: exact ? 'Ese horario está libre.' : nil }.compact
  end

  # Con día y hora, si ese horario exacto está libre.
  def exact_slot(from)
    start = parse(from)
    start && from.to_s.include?('T') ? service.slot_for(start) : nil
  end

  def book(from, notes)
    return { error: 'Ya tiene cita agendada: usa mover_cita o cancelar_cita.' } if meeting&.scheduled?

    slot = free_slot(from)
    return slot if slot[:error]
    return { ok: true, prueba: true, cita: local(slot[:slot]), con: slot[:agent_name] } if test?

    created = create_meeting(slot, notes)
    after_booking(created)
    { ok: true, cita: local(created.starts_at), con: created.organizer&.name }
  end

  # Después de mandar el mensaje: los archivos de la cita, la nota y etiqueta, y el recordatorio.
  def after_booking(created)
    trace.event(:cita, local(created.starts_at))
    @turn.after_send { booked_files }
    @turn.after_send { Motor2::Outcomes.new(@turn.tracking, @turn.conversation, config).booked(created) }
    notice(created)
  end

  def move(from)
    return { error: 'No tiene cita agendada.' } unless meeting&.scheduled?

    slot = free_slot(from)
    return slot if slot[:error]
    return { ok: true, prueba: true, cita: local(slot[:slot]) } if test?

    reschedule(slot)
    { ok: true, cita: local(meeting.starts_at) }
  end

  def reschedule(slot)
    meeting.update!(starts_at: slot[:slot], ends_at: slot[:end_time])
    Cases::MeetingSyncJob.perform_later(meeting.id, 'update', meeting.saved_changes.except('updated_at'))
    trace.event(:cita, "movida a #{local(slot[:slot])}")
    notice(meeting)
  end

  def cancel(reason)
    return { error: 'No tiene cita agendada.' } unless meeting&.scheduled?
    return { ok: true, prueba: true } if test?

    meeting.update!(status: :cancelled, cancel_reason: reason.to_s.presence || 'El cliente la canceló')
    Cases::MeetingSyncJob.perform_later(meeting.id, 'cancel')
    trace.event(:cita, 'cancelada')
    { ok: true }
  end

  # El recordatorio y el «¿otro horario?» si no llega (Motor2::AppointmentNotice), con la hora nueva.
  def notice(scheduled)
    tracking = @turn.tracking
    @turn.after_send { Motor2::AppointmentNotice.schedule!(tracking, scheduled) } if tracking
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
    { error: 'Ese horario se acaba de ocupar.', horarios: others.map { |s| slot_row(s) },
      nota: 'Dile que ese horario se acaba de ocupar y ofrécele estos.' }
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
    state['appointment'] = { 'meeting_id' => created.id }
    @meeting = created
  end

  def meeting_attrs(slot, notes, contact)
    data = state.data.map { |k, v| "• #{k}: #{v}" }.join("\n")
    { title: "Cita (#{kind}) · #{contact&.name}".first(255), description: [notes, data].compact_blank.join("\n"),
      starts_at: slot[:slot], ends_at: slot[:end_time], location: setting(:location).presence,
      is_visit: kind == 'visita', attendee_emails: [contact&.email].compact_blank }
  end

  def booked_files
    ContactTrackings::EventFiles.send_for(@turn.tracking, :booking, conversation: @turn.conversation,
                                                                    sender: Motor2::Delivery.sender(config.account))
  end
end
