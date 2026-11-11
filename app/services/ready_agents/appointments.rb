# frozen_string_literal: true

# Agentes listos — agendar la cita del prospecto en el calendario de las personas que se
# eligieron al activar el agente (con Google conectado). Los horarios libres salen de su
# Google (ContactTrackings::AvailabilitySlotService, el mismo del motor de siempre) dentro del
# horario de atención de la bandeja (o lun–vie 9–18), y la cita es una tarea agendada de la
# Agenda con su contacto (AgendaItems::Creator), que se espeja sola en Google.
#
#   slots(desde)          → 3 horarios libres, repartidos entre las personas
#   book(inicio, notas)   → la agenda (vuelve a revisar que esté libre)
#   move(inicio)          → la mueve (solo la que agendó el agente en esa conversación)
#   cancel(motivo)        → la cancela
# En el chat de prueba (sin sesión) lee los horarios reales pero no crea ni cambia nada.
class ReadyAgents::Appointments
  DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
  KINDS = %w[llamada videollamada visita oficina].freeze
  OFFER = 3 # horarios por respuesta: un mensaje corto

  def initialize(agent, session: nil)
    @agent = agent
    @session = session
    @conversation = session&.conversation
  end

  def self.available?(agent)
    agent.objective == 'appointment' && integration_ids(agent).any?
  end

  def self.integration_ids(agent)
    UserCalendarIntegration.where(account_id: agent.account_id, user_id: Array(agent.setting(:appointment_user_ids))).pluck(:id)
  end

  def self.label(time)
    "#{DAYS[time.wday]} #{time.day} de #{MONTHS[time.month - 1]}, #{time.strftime('%H:%M')}"
  end

  # La herramienta que pidió el modelo.
  def tool(name, args)
    case name
    when 'ver_horarios' then slots(args['desde'])
    when 'agendar_cita' then book(args['inicio'], args['notas'])
    when 'mover_cita' then move(args['inicio'])
    else cancel(args['motivo'])
    end
  end

  def slots(from = nil)
    start = parse(from)
    exact = start && from.to_s.include?('T') ? service.slot_for(start) : nil
    list = exact ? [exact] : service.call(from: start)
    return { horarios: [], nota: 'No hay horarios libres en los próximos días: ofrécele pasarlo con el equipo.' } if list.empty?

    { horarios: list.first(OFFER).map { |s| slot_row(s) }, duracion_minutos: minutes,
      nota: exact ? 'Ese horario está libre.' : nil }.compact
  end

  def book(from, notes)
    return { error: 'Ya agendaste una cita en esta conversación: usa mover_cita o cancelar_cita.' } if meeting&.scheduled?

    slot = free_slot(from)
    return slot if slot[:error]
    return { ok: true, prueba: true, cita: self.class.label(slot[:slot].in_time_zone(zone)), con: slot[:agent_name] } unless @session

    created = create_meeting(slot, notes)
    { ok: true, cita: self.class.label(created.starts_at.in_time_zone(zone)), con: created.organizer&.name, folio: created.folio }
  end

  def move(from)
    return { error: 'No hay cita agendada por ti en esta conversación.' } unless meeting&.scheduled?

    slot = free_slot(from)
    return slot if slot[:error]
    return { ok: true, prueba: true, cita: self.class.label(slot[:slot].in_time_zone(zone)) } unless @session

    meeting.update!(starts_at: slot[:slot], ends_at: slot[:end_time])
    Cases::MeetingSyncJob.perform_later(meeting.id, 'update', meeting.saved_changes.except('updated_at'))
    @session.add_log(:moved, meeting_label)
    { ok: true, cita: meeting_label }
  end

  def cancel(reason)
    return { error: 'No hay cita agendada por ti en esta conversación.' } unless meeting&.scheduled?
    return { ok: true, prueba: true } unless @session

    meeting.update!(status: :cancelled, cancel_reason: reason.to_s.presence || 'El cliente la canceló')
    Cases::MeetingSyncJob.perform_later(meeting.id, 'cancel')
    @session.add_log(:cancelled_appointment, reason)
    { ok: true }
  end

  private

  def meeting_label = self.class.label(meeting.starts_at.in_time_zone(zone))

  def minutes = [@agent.setting(:appointment_minutes).to_i, 15].max.clamp(15, 240)

  def meeting
    @meeting ||= @session&.case_meeting
  end

  def service
    @service ||= ContactTrackings::AvailabilitySlotService.new(
      calendar_integration_ids: self.class.integration_ids(@agent), timezone: zone.tzinfo.name,
      slot_duration: minutes, working_hours: working_hours
    )
  end

  def working_hours
    inbox = @conversation&.inbox || @agent.inboxes.first
    inbox.working_hours if inbox&.working_hours_enabled?
  end

  def zone
    inbox = @conversation&.inbox || @agent.inboxes.first
    ActiveSupport::TimeZone[inbox&.timezone.to_s] || Time.zone
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

    slot = service.slot_for(start)
    slot || { error: 'Ese horario ya no está libre: consulta ver_horarios y ofrécele otros.' }
  end

  def slot_row(slot)
    local = slot[:slot].in_time_zone(zone)
    { inicio: local.strftime('%Y-%m-%dT%H:%M'), texto: self.class.label(local), con: slot[:agent_name] }
  end

  def create_meeting(slot, notes)
    organizer = UserCalendarIntegration.find(slot[:calendar_integration_id]).user
    contact = @conversation.contact
    meeting = AgendaItems::Creator.new(
      account: @agent.account, user: organizer, organizer: organizer,
      client: { contact: contact, organization: contact&.organization }, attrs: meeting_attrs(slot, notes, contact)
    ).call
    @session.update!(case_meeting: meeting)
    meeting
  end

  def meeting_attrs(slot, notes, contact)
    kind = KINDS.include?(@agent.setting(:appointment_kind)) ? @agent.setting(:appointment_kind) : 'llamada'
    { title: "Cita (#{kind}) · #{contact&.name}".first(255), description: [notes, answers_text].compact_blank.join("\n"),
      starts_at: slot[:slot], ends_at: slot[:end_time], location: @agent.setting(:appointment_location).presence,
      is_visit: kind == 'visita', attendee_emails: [contact&.email].compact_blank }
  end

  def answers_text
    @session.answers.to_h.map { |q, a| "• #{q}: #{a}" }.join("\n")
  end
end
