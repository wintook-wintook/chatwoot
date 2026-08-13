# frozen_string_literal: true

# @tickets_cases F4 — {freq, interval, by_day, until/count, tz} → RRULE, y su
# expansión local de fechas (plan §4.3 y §11.5).
#
# Dos usos:
#   * `rule`   → la cadena que se manda a Google como recurrencia del maestro.
#   * `expand` → las fechas calculadas AQUÍ. Se necesita para dos cosas: la vista
#     previa del formulario ("se crearán 8: 17 ago, 24 ago…") y el modo degradado
#     (si Google falla, las ocurrencias se generan igual sin `google_event_id`).
#
# ⚠️ Trampa del `UNTIL` (§11.5): va en **UTC**. Escribir la fecha local con una
# `Z` pegada se come la última ocurrencia de las series vespertinas, en silencio
# y sin error. Por eso `COUNT` es preferible siempre que el usuario piense en
# número de sesiones.
class Cases::Meetings::RRuleBuilder
  MAX_OCCURRENCES = CaseMeetingSeries::MAX_OCCURRENCES

  FREQ_MAP = { 'daily' => 'DAILY', 'weekly' => 'WEEKLY', 'monthly' => 'MONTHLY' }.freeze
  # Códigos de día del RFC 5545 en el orden de `Date#wday` (0 = domingo).
  WDAYS = %w[SU MO TU WE TH FR SA].freeze

  def initialize(series)
    @series = series
  end

  # ⚠️ Zona de la SERIE, no la del servidor. El día de la semana y los saltos se
  # evalúan aquí: una reunión de los viernes 18:00 en México cae en sábado UTC, y
  # calcular en UTC generaría las ocurrencias el día equivocado (mismo modo de
  # falla silenciosa que el UNTIL de §11.5).
  def zone
    @zone ||= (@series.time_zone.presence && ActiveSupport::TimeZone[@series.time_zone]) || Time.zone
  end

  # "RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=TU;COUNT=8"
  def rule
    parts = ["FREQ=#{FREQ_MAP.fetch(@series.freq, 'WEEKLY')}"]
    parts << "INTERVAL=#{@series.interval}" if @series.interval.to_i > 1
    parts << "BYDAY=#{by_day.join(',')}" if by_day.any?
    parts << (@series.count.present? ? "COUNT=#{@series.count}" : "UNTIL=#{until_utc}")
    "RRULE:#{parts.join(';')}"
  end

  # Fechas de inicio de cada ocurrencia, calculadas localmente.
  def expand
    occurrences = []
    cursor = @series.starts_at.in_time_zone(zone)
    limit = [@series.count.presence || MAX_OCCURRENCES, MAX_OCCURRENCES].min
    guard = 0

    while occurrences.size < limit && guard < 1000
      guard += 1
      break if @series.until_at.present? && cursor > @series.until_at

      occurrences << cursor if matches_by_day?(cursor)
      cursor = advance(cursor)
    end
    occurrences
  end

  # Duración de cada ocurrencia: la de la primera. Google exige hora de fin, así
  # que el formulario nunca deja esto vacío (§11.3: default de 1 hora).
  def duration
    return 1.hour if @series.ends_at.blank? || @series.starts_at.blank?

    @series.ends_at - @series.starts_at
  end

  # `UNTIL` que conserva las ocurrencias hasta `last_kept` inclusive y corta el
  # resto (§11.2, truncación de una serie ya empezada). Se calcula en UTC y se
  # deja un margen de un minuto DESPUÉS de la última conservada: calcularlo sobre
  # la fecha local se come esa reunión del historial.
  def self.truncate_rule(series, last_kept)
    builder = new(series)
    parts = builder.rule.sub('RRULE:', '').split(';').reject { |p| p.start_with?('COUNT=', 'UNTIL=') }
    parts << "UNTIL=#{(last_kept.utc + 1.minute).strftime('%Y%m%dT%H%M%SZ')}"
    "RRULE:#{parts.join(';')}"
  end

  private

  def by_day
    days = Array(@series.by_day).map { |d| d.to_s.upcase }.select { |d| WDAYS.include?(d) }
    # Sin días marcados, una serie semanal repite el día de la primera ocurrencia
    # (leído en la zona de la serie).
    return days if days.any? || !@series.freq_weekly?

    [WDAYS[@series.starts_at.in_time_zone(zone).wday]]
  end

  def until_utc
    @series.until_at.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  # En semanal con varios días (["TU","TH"]) el cursor avanza de día en día y solo
  # se queda con los que caen en la lista; en el resto, salta de periodo en periodo.
  def matches_by_day?(time)
    return true unless @series.freq_weekly?
    return true if by_day.empty?

    by_day.include?(WDAYS[time.in_time_zone(zone).wday])
  end

  def advance(cursor)
    step = @series.interval.to_i.clamp(1, 52)
    case @series.freq
    when 'daily'   then cursor + step.days
    when 'monthly' then cursor + step.months
    else weekly_advance(cursor, step)
    end
  end

  # Semanal: día a día dentro de la semana, y al cerrar la semana salta el
  # intervalo completo (así "cada 2 semanas, martes y jueves" no se descuadra).
  def weekly_advance(cursor, step)
    nxt = cursor + 1.day
    return nxt if by_day.size <= 1 && step == 1
    return nxt unless nxt.in_time_zone(zone).wday.zero? # domingo: semana nueva

    nxt + ((step - 1) * 7).days
  end
end
