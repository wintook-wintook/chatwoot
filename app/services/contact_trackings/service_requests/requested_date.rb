# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LA FECHA DEL SERVICIO, Y LA QUE YA PASÓ (27/11/2026)
# ================================================================================
# Lo usa Registry. Antes una fecha u hora que ya había pasado («hoy a las 14:00» a las 17:00,
# «sábado 07/11» el 26 de noviembre) se guardaba igual como fecha del servicio, y cada turno decía
# «esa fecha ya pasó / un asesor revisa la disponibilidad» sin pedir otra (pruebas con la guía de
# SSUSA, conv. 196 y 199). Ahora queda aparte (past_date / past_time) y Turn pide otra fecha.
# Con @solicitudes(fecha=mes/dia) las fechas numéricas se leen mes/día (ver DateResolver).
# ================================================================================

module ContactTrackings::ServiceRequests::RequestedDate
  PAST_KEYS = %w[past_date past_time].freeze

  private

  # La fecha o la hora que faltaban, si este mensaje las trae. Lo que ya tenía no se toca.
  # Si la que dio antes ya había pasado, «a las 20:00» sola completa ese mismo día; una fecha u
  # hora nueva que también ya pasó no se toma.
  def with_new_date(datos)
    nueva = dates.call(@text, @text)
    return with_new_time(datos, nueva) if datos['date'].present?
    return datos unless nueva.date || (nueva.time && datos['past_date'])

    dia, hora = day_and_hour(datos, nueva)
    return datos if result(dia, hora).past?(@timezone)

    datos.except(*PAST_KEYS).merge('date' => dia.iso8601, 'date_text' => @text.truncate(80), 'ambiguous' => nueva.ambiguous,
                                   'time' => hora, 'time_text' => hora)
  end

  # El día nuevo (o el de la fecha que ya había pasado) y la hora: la que ya tenía, la nueva o la de antes.
  def day_and_hour(datos, nueva)
    [nueva.date || Date.iso8601(datos['past_date']), datos['time'].presence || nueva.time || datos['past_time']]
  end

  # Ya tenía el día: solo la hora que faltaba (si no es una hora de hoy que ya pasó).
  def with_new_time(datos, nueva)
    return datos unless datos['time'].blank? && nueva.time
    return datos if result(Date.iso8601(datos['date']), nueva.time).past?(@timezone)

    datos.merge('time' => nueva.time, 'time_text' => nueva.time)
  end

  def dated(datos, fecha)
    fecha.past?(@timezone) ? past(datos) : datos
  end

  def past(datos)
    datos.merge('past_date' => datos['date'], 'past_time' => datos['time'], 'date' => nil, 'time' => nil)
  end

  # Una fecha nueva borra el aviso de la vieja; una nueva que ya pasó no deja la anterior en su lugar.
  def merged_dates(combinado, datos)
    combinado = combinado.except(*PAST_KEYS) if datos['date'].present?
    datos['past_date'].present? ? combinado.merge('date' => nil, 'time' => nil) : combinado
  end

  def result(dia, hora)
    ContactTrackings::ServiceRequests::DateResolver::Result.new(date: dia, time: hora)
  end

  def dates
    @dates ||= ContactTrackings::ServiceRequests::DateResolver.new(timezone: @timezone, month_first: options.month_first?)
  end
end
