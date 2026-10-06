# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LOS HORARIOS DE CADA SERVICIO (pieza 5, F3, 26/09/2026)
# ================================================================================
# Para cada caso-servicio con fecha, en la ruta que tiene @solicitudes y @agendar_calendar:
#   · calendarios: {{hoja_buscar:}} de la ruta, con el texto de ESTE servicio («hiab 12 t»)
#   · duración: la de @agendar_calendar(duracion=…) o la que dijo el cliente, o la del agente
#   · horario: 24 h si la ruta lo dice; si no, el del canal
#   · opciones (observaciones SSUSA 5, 06/10/2026 — reemplaza la decisión 2):
#       con hora pedida y libre → UNA opción, exacta: Turn la aparta directo
#       con hora pedida ocupada → «a las 08:00 no hay» y hasta 3 de las siguientes (1A, 1B, 1C)
#       sin hora                → ninguna: Turn pide la hora (need_time)
#     Una renta por días no lleva hora: ofrece los equipos libres todo el periodo (F7).
#   · unidades (observación SSUSA 4): la 1.ª columna que regresa {{hoja_buscar:}} es el
#     calendario; las demás describen la unidad antes de su horario
#     ({{hoja_buscar: Servicio Gruas | tipo=? | Calendar_ID, tipo, peso_max_t, placas}}).
# Las opciones quedan en metadata['oferta'] del caso; la elección la resuelve Choice.
# ================================================================================

class ContactTrackings::ServiceRequests::Scheduler
  MAX_OPTIONS = 3
  LETTERS = %w[A B C].freeze

  # La nota explica por qué no hay opciones (o aclara algo) en la línea del servicio.
  # exact: la hora pedida está libre (una sola opción). units: { calendario => descripción }.
  # held: la opción que Turn apartó directo (exact).
  Plan = Struct.new(:ticket, :offers, :note, :requested, :exact, :need_time, :units, :held, keyword_init: true)

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
    return Plan.new(ticket: ticket, offers: [], need_time: true, requested: at) if datos['time'].blank?

    offer(ticket, number, buscador, at)
  end

  private

  def offer(ticket, number, buscador, at)
    exacto = buscador.slot_for(at)
    slots = exacto ? [exacto] : following(buscador, at)
    ofertas = slots.each_with_index.map { |slot, i| payload(slot, "#{number}#{LETTERS[i]}") }
    ticket.update!(metadata: ticket.metadata.merge('oferta' => ofertas))
    Plan.new(ticket: ticket, offers: ofertas, note: note_for(slots, exacto, at), requested: at, exact: exacto.present?,
             units: units_for(ofertas))
  end

  # F7 — renta: un bloque de días completos; las opciones son los equipos libres TODO el periodo.
  def rental_offer(ticket, number, buscador, desde, dias)
    libres = buscador.free_for_period(desde, desde + dias.days).first(MAX_OPTIONS)
    ofertas = libres.each_with_index.map { |slot, i| payload(slot, "#{number}#{LETTERS[i]}").merge('all_day' => true) }
    ticket.update!(metadata: ticket.metadata.merge('oferta' => ofertas))
    Plan.new(ticket: ticket, offers: ofertas, note: libres.empty? ? 'ningún equipo libre en todo ese periodo' : nil, requested: desde,
             units: units_for(ofertas))
  end

  # La hora pedida está ocupada: las siguientes libres.
  def following(buscador, desde)
    buscador.call(from: desde).uniq { |s| [s[:slot], s[:google_calendar_id]] }.first(MAX_OPTIONS)
  end

  def note_for(slots, exacto, at)
    return "sí hay a las #{at.strftime('%H:%M')}" if exacto
    return "a las #{at.strftime('%H:%M')} no hay, ni más tarde ese día" if slots.empty?

    "a las #{at.strftime('%H:%M')} no hay; lo que sí hay"
  end

  # Solo las unidades que se ofrecen, en el orden en que aparecen.
  def units_for(ofertas)
    unidades = @units.to_h
    ofertas.filter_map { |oferta| oferta['gcal'] }.uniq.index_with { |gcal| unidades[gcal] }.compact_blank
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

    filas = rows_by_calendar(resultado.rows)
    @units = filas.transform_values { |fila| describe_unit(fila) }.compact_blank
    salida = ContactTrackings::SheetCalendars.narrow(@tracking, filas.keys.compact_blank)
    salida.status == :ok ? salida : nil
  end

  # { id del calendario => fila }: el calendario es la 1.ª columna que regresa la directiva.
  def rows_by_calendar(filas)
    filas.index_by { |fila| ContactTrackings::SheetLookup.calendar_id(cell(fila, @spec.returns.first)) }
  end

  # «Low boy (cama muy baja) · Peso max t: 60 · Placas: 66UL2B»: las columnas que la ruta pidió
  # después del calendario. La primera va sin nombre (suele ser el tipo).
  def describe_unit(fila)
    partes = @spec.returns.drop(1).filter_map do |columna|
      valor = cell(fila, columna)
      [columna, valor] if valor.present?
    end
    partes.each_with_index.map { |(columna, valor), i| i.zero? ? valor.to_s : "#{columna.tr('_', ' ').capitalize}: #{valor}" }.join(' · ')
  end

  def cell(fila, columna)
    clave = fila.keys.find { |k| k.to_s.strip.casecmp?(columna.to_s.strip) }
    clave && fila[clave]
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
