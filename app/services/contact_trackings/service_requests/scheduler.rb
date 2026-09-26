# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LOS HORARIOS DE CADA SERVICIO (pieza 5, F3, 26/09/2026)
# ================================================================================
# Para cada caso-servicio con fecha, en la ruta que tiene @solicitudes y @agendar_calendar:
#   · calendarios: {{hoja_buscar:}} de la ruta, con el texto de ESTE servicio («hiab 12 t»)
#   · duración: la de @agendar_calendar(duracion=…) o la que dijo el cliente, o la del agente
#   · horario: 24 h si la ruta lo dice; si no, el del canal
#   · opciones: hasta 3 (1A, 1B, 1C). Con hora pedida y libre, esa es la A (decisión 2: se
#     OFRECE para que la confirme, no se aparta sola).
# Las opciones quedan en metadata['oferta'] del caso; la elección la resuelve Choice.
# ================================================================================

class ContactTrackings::ServiceRequests::Scheduler
  MAX_OPTIONS = 3
  LETTERS = %w[A B C].freeze

  # La nota explica por qué no hay opciones (o aclara algo) en la línea del servicio.
  Plan = Struct.new(:ticket, :offers, :note, :requested, keyword_init: true)

  def initialize(tracking:, route:, timezone:)
    @tracking = tracking
    @route = route
    @timezone = timezone
    @options = ContactTrackings::CalendarOptions.parse(route&.escalation)
    @spec = ContactTrackings::SheetLookup.parse_all(route&.escalation).first
  end

  def agenda?
    @route&.escalation.to_s.match?(/@agendar_calendar\b/i)
  end

  def plan(ticket, number)
    datos = ticket.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
    at = requested_at(datos)
    return Plan.new(ticket: ticket, offers: [], note: nil) if at.nil?
    return Plan.new(ticket: ticket, offers: [], note: 'esa fecha ya pasó') if at < Time.current

    buscador = slot_service(datos)
    return Plan.new(ticket: ticket, offers: [], note: 'no tengo ese equipo en el catálogo') if buscador.nil?

    dias = ContactTrackings::CalendarOptions.period_days(datos['duration_text'], at.to_date)
    return rental_offer(ticket, number, buscador, at.beginning_of_day, dias) if dias

    offer(ticket, number, buscador, at, datos)
  end

  private

  def offer(ticket, number, buscador, at, datos)
    con_hora = datos['time'].present?
    exacto = con_hora ? buscador.slot_for(at) : nil
    slots = candidates(buscador, exacto, con_hora ? at : at.beginning_of_day)
    ofertas = slots.each_with_index.map { |slot, i| payload(slot, "#{number}#{LETTERS[i]}") }
    ticket.update!(metadata: ticket.metadata.merge('oferta' => ofertas))
    Plan.new(ticket: ticket, offers: ofertas, note: note_for(slots, con_hora && exacto.nil?, at), requested: at)
  end

  # F7 — renta: un bloque de días completos; las opciones son los equipos libres TODO el periodo.
  def rental_offer(ticket, number, buscador, desde, dias)
    libres = buscador.free_for_period(desde, desde + dias.days).first(MAX_OPTIONS)
    ofertas = libres.each_with_index.map { |slot, i| payload(slot, "#{number}#{LETTERS[i]}").merge('all_day' => true) }
    ticket.update!(metadata: ticket.metadata.merge('oferta' => ofertas))
    Plan.new(ticket: ticket, offers: ofertas, note: libres.empty? ? 'ningún equipo libre en todo ese periodo' : nil, requested: desde)
  end

  # La hora pedida (si está libre) primero, y después las siguientes libres.
  def candidates(buscador, exacto, desde)
    ([exacto] + buscador.call(from: desde)).compact.uniq { |s| [s[:slot], s[:google_calendar_id]] }.first(MAX_OPTIONS)
  end

  def note_for(slots, ocupada, at)
    return 'ese día no tengo horarios' if slots.empty?

    "#{at.strftime('%H:%M')} ocupado" if ocupada
  end

  def requested_at(datos)
    return nil if datos['date'].blank?

    ContactTrackings::ServiceRequests::DateResolver::Result.new(date: Date.iso8601(datos['date']), time: datos['time']).at(@timezone)
  end

  # nil si la hoja no tiene ese equipo o sus calendarios no están en el agente.
  def slot_service(datos)
    calendarios = calendars_for(datos)
    return nil if calendarios.nil?

    ContactTrackings::AvailabilitySlotService.new(
      calendar_integration_ids: calendarios.integration_ids, timezone: @timezone, slot_duration: duration(datos),
      working_hours: @options&.all_day ? ContactTrackings::AvailabilitySlotService::ALL_DAY : working_hours,
      booking_calendars: calendarios.booking_calendars
    )
  end

  def calendars_for(datos)
    return nil if @spec.nil?

    texto = [datos['equipment_type'], datos['capacity_t'] && "#{datos['capacity_t']} t", datos['weight_t'] && "#{datos['weight_t']} t"]
    resultado = ContactTrackings::SheetLookup.new(@tracking.account, @spec, text: texto.compact.join(' ')).call
    return nil unless resultado.ok?

    salida = ContactTrackings::SheetCalendars.narrow(@tracking, resultado.found.map { |v| ContactTrackings::SheetLookup.calendar_id(v) })
    salida.status == :ok ? salida : nil
  end

  def duration(datos)
    del_agente = @tracking.tracking_template&.calendar_event_duration || 30
    return del_agente if @options.nil?
    return @options.duration if @options.duration
    return del_agente unless @options.ask_duration

    ContactTrackings::CalendarOptions.duration_in(datos['duration_text']) || del_agente
  end

  def working_hours
    inbox = @tracking.inbox
    inbox&.working_hours_enabled? ? inbox.working_hours : nil
  end

  def payload(slot, code)
    { 'code' => code, 'slot' => slot[:slot].utc.iso8601, 'end_time' => slot[:end_time].utc.iso8601,
      'cal_id' => slot[:calendar_integration_id], 'gcal' => slot[:google_calendar_id], 'calendar_name' => slot[:calendar_name] }
  end
end
