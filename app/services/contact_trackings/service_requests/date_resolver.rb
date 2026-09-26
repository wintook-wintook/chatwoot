# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LA FECHA Y LA HORA DE UN SERVICIO, SIN IA (pieza 5, F2)
# ================================================================================
# El extractor copia lo que escribió el cliente; aquí se vuelve fecha. Formatos del corpus:
#   «29 de mayo 2026» · «03 DE AGOSTO» · «01-JUN-26» · «30/06/2026» · «el lunes 01 de junio»
#   «mañana» · «hoy» · «pasado mañana» · «el día lunes» (ambiguo: día sin número)
#   hora: «08:00 am» · «03:00 hrs» · «11:00 AM» · «6:00 pm» · «10:30»
# Sin año: el de hoy; si esa fecha ya pasó, la del año siguiente (se agenda a futuro).
# ================================================================================

class ContactTrackings::ServiceRequests::DateResolver
  MONTHS = { 'ene' => 1, 'feb' => 2, 'mar' => 3, 'abr' => 4, 'may' => 5, 'jun' => 6, 'jul' => 7,
             'ago' => 8, 'sep' => 9, 'set' => 9, 'oct' => 10, 'nov' => 11, 'dic' => 12 }.freeze
  WEEKDAYS = { 'lunes' => 1, 'martes' => 2, 'miercoles' => 3, 'jueves' => 4, 'viernes' => 5,
               'sabado' => 6, 'domingo' => 7 }.freeze
  NUMERIC_RE = %r{\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b}
  WORDS_RE = /\b(\d{1,2})\s*(?:de\s+|-)?\s*(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[a-z]*\.?(?:\s*(?:de|del|-)?\s*(\d{2,4}))?/i
  TIME_RE = /\b(\d{1,2})(?::(\d{2}))?\s*(a\.?\s?m\.?|p\.?\s?m\.?|hrs?\.?|horas)?(?![\d:])/i

  Result = Struct.new(:date, :time, :ambiguous, keyword_init: true) do
    # nil si no hay fecha; con hora, a esa hora en la zona del agente.
    def at(timezone)
      return nil if date.nil?

      hora, minuto = (time || '00:00').split(':').map(&:to_i)
      Time.find_zone(timezone).local(date.year, date.month, date.day, hora, minuto)
    end
  end

  def initialize(timezone:, today: nil)
    @timezone = timezone
    @today = today || Time.current.in_time_zone(timezone).to_date
  end

  def call(date_text, time_text = nil)
    texto = fold(date_text)
    fecha, ambiguo = date_from(texto)
    Result.new(date: fecha, time: time_from(time_text), ambiguous: ambiguo)
  end

  private

  def date_from(texto)
    return [nil, false] if texto.blank?
    return [@today + 2, false] if texto.include?('pasado manana')
    return [@today + 1, false] if texto.match?(/\bmanana\b/)
    return [@today, false] if texto.match?(/\bhoy\b/)

    explicit_date(texto) || weekday_date(texto) || [nil, false]
  end

  def explicit_date(texto)
    if (m = texto.match(WORDS_RE))
      [build(m[1].to_i, MONTHS[m[2].downcase], m[3]), false]
    elsif (m = texto.match(NUMERIC_RE))
      [build(m[1].to_i, m[2].to_i, m[3]), false]
    end
  end

  # «el día lunes»: el próximo (no hoy), y se marca ambiguo para confirmarlo.
  def weekday_date(texto)
    dia = WEEKDAYS.find { |nombre, _| texto.match?(/\b#{nombre}\b/) }&.last
    return nil if dia.nil?

    faltan = (dia - @today.cwday) % 7
    [@today + (faltan.zero? ? 7 : faltan), true]
  end

  def build(day, month, year)
    return nil if month.nil? || !(1..12).cover?(month)

    anio = year.present? ? normalize_year(year.to_i) : @today.year
    fecha = Date.new(anio, month, day)
    year.blank? && fecha < @today ? fecha.next_year : fecha
  rescue Date::Error
    nil
  end

  def normalize_year(year)
    year < 100 ? 2000 + year : year
  end

  def time_from(text)
    m = text.to_s.match(TIME_RE)
    return nil if m.nil? || (m[2].nil? && m[3].nil?)

    format('%<h>02d:%<m>02d', h: twenty_four(m[1].to_i, m[3].to_s.downcase), m: m[2].to_i)
  end

  def twenty_four(hora, sufijo)
    return hora + 12 if sufijo.start_with?('p') && hora < 12
    return 0 if sufijo.start_with?('a') && hora == 12

    hora
  end

  def fold(text)
    I18n.transliterate(text.to_s).downcase
  end
end
