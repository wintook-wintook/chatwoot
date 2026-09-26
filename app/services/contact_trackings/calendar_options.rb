# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — @agendar_calendar(duracion=…, horario=…) (pieza 3, 26/09/2026)
# ================================================================================
# La agenda estaba hecha para citas de 30 minutos en horario de oficina. SSUSA agenda
# servicios: una grúa a las 03:00, un domingo, de 18:00 a 00:00, una jornada de 16 horas.
#
#   @agendar_calendar                               como siempre (duración del agente, horario del canal)
#   @agendar_calendar(duracion=90)                  90 minutos (también «2h», «1.5h»)
#   @agendar_calendar(duracion=?)                   la duración sale del mensaje del cliente;
#                                                   si no la dijo, la del agente
#   @agendar_calendar(horario=24h)                  cualquier hora, cualquier día
#   @agendar_calendar(duracion=?, horario=24h)      las dos
#   @agendar_calendar(modo=tentativo)               aparta sin dejarlo en firme (pieza 4,
#                                                   ver ServiceConfirmation)
#
# Del mensaje (sin IA): «duración aproximada de una hora» → 60 · «jornada de 16 horas» → 960
# · «6:00 pm – 12:00 am» / «de 18:00 a 00:00» → 360 · «2 hrs» → 120 · «45 minutos» → 45.
# Una hora del día («03:00 hrs», «10:30») no es una duración. Tope: 24 horas.
# ================================================================================

module ContactTrackings::CalendarOptions
  DIRECTIVE_RE = /@agendar_calendar\s*\(([^)]*)\)/i
  KNOWN = %w[duracion horario].freeze
  MAX_MINUTES = 24 * 60

  # tentative (pieza 4): modo=tentativo — el horario se aparta, no queda en firme.
  Options = Struct.new(:duration, :ask_duration, :all_day, :tentative, keyword_init: true)

  CLOCK = '(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.\s?m\.|p\.\s?m\.|hrs?|horas)?'
  RANGE_RE = /\b#{CLOCK}\s*(?:-|–|a|al|hasta)\s*#{CLOCK}/i
  HOURS_RE = /(?<![:\d])(\d+(?:[.,]\d+)?)\s*(?:horas?|hrs?|h)\b/i
  MINUTES_RE = /(?<![:\d])(\d+)\s*(?:minutos?|mins?)\b/i
  WORDS = { /\bhora y media\b/i => 90, /\bmedia hora\b/i => 30, /\buna hora\b/i => 60 }.freeze

  module_function

  # Las opciones escritas en @agendar_calendar(...) de un texto (la ruta), o nil si no trae.
  def parse(text)
    inner = text.to_s[DIRECTIVE_RE, 1]
    return nil if inner.nil?

    params = pairs(inner)
    Options.new(duration: fixed_duration(params['duracion']), ask_duration: params['duracion'] == '?',
                all_day: params['horario'].to_s.casecmp?('24h'), tentative: params['modo'].to_s.casecmp?('tentativo'))
  end

  # Lo mal escrito, para el comprobador: [['horario', 'noche'], ['color', 'rojo']].
  def invalid(text)
    inner = text.to_s[DIRECTIVE_RE, 1]
    return [] if inner.nil?

    pairs(inner).reject do |clave, valor|
      case clave
      when 'duracion' then valor == '?' || fixed_duration(valor)
      when 'horario' then valor.casecmp?('24h')
      when 'modo' then valor.casecmp?('tentativo')
      end
    end.to_a
  end

  def pairs(inner)
    inner.split(',').filter_map do |par|
      clave, valor = par.split('=', 2).map { |parte| parte.to_s.strip }
      [I18n.transliterate(clave).downcase, valor] if clave.present?
    end.to_h
  end

  # «90», «90 min», «2h», «1.5h» → minutos; nil si no se entiende.
  def fixed_duration(value)
    texto = value.to_s.strip.downcase
    return nil if texto.blank? || texto == '?'
    return (texto.to_f * 60).round if texto.match?(/\A\d+(?:[.,]\d+)?\s*h/)

    minutos = texto[/\A(\d+)\s*(?:min)?\z/, 1]&.to_i
    minutos&.positive? ? [minutos, MAX_MINUTES].min : nil
  end

  # La duración que dijo el cliente, en minutos, o nil.
  def duration_in(text)
    minutos = READERS.lazy.filter_map { |lector| send(lector, text.to_s) }.first
    minutos&.positive? ? [minutos, MAX_MINUTES].min : nil
  end

  # En orden: un rango de horas manda sobre «2 horas», y eso sobre «una hora».
  READERS = %i[range_minutes hours_minutes plain_minutes word_minutes].freeze

  def plain_minutes(text)
    text[MINUTES_RE, 1]&.to_i
  end

  def word_minutes(text)
    WORDS.find { |regex, _| text.match?(regex) }&.last
  end

  # proyecto@solicitudes (pieza 5, F7) — una renta NO se ofrece por horarios: es un bloque de
  # días completos. «6 meses», «3 semanas», «15 días», «renta mensual», «un año». nil si no es renta.
  PERIOD_RE = /(\d+|un|una)\s*(d[ií]as?|semanas?|mes(?:es)?|a[nñ]os?)\b|\b(mensual|semanal|anual)\b/i
  PERIOD_WORDS = { 'mensual' => [1, 'mes'], 'semanal' => [1, 'semana'], 'anual' => [1, 'ano'] }.freeze

  # Cuántos días dura desde `desde` (los meses se cuentan de calendario: 1 nov → 1 may).
  def period_days(text, desde)
    m = I18n.transliterate(text.to_s).downcase.match(PERIOD_RE)
    return nil if m.nil?

    cantidad, unidad = m[3] ? PERIOD_WORDS[m[3]] : [m[1].to_i.nonzero? || 1, m[2]]
    hasta = advance(desde, cantidad, unidad)
    (hasta - desde).to_i
  end

  def advance(desde, cantidad, unidad)
    case unidad
    when /\Adia/ then desde + cantidad
    when /\Asemana/ then desde + (cantidad * 7)
    when /\Ames/ then desde >> cantidad
    else desde >> (cantidad * 12)
    end
  end

  def hours_minutes(text)
    horas = text[HOURS_RE, 1]
    horas && (horas.tr(',', '.').to_f * 60).round
  end

  # «6:00 pm – 12:00 am», «de 18:00 a 00:00»: solo si los dos extremos son horas del día
  # (con «:mm» o am/pm), para no leer «de 2 a 3 unidades» como un horario.
  def range_minutes(text)
    m = text.match(RANGE_RE)
    return nil unless m && clock?(m[2], m[3]) && clock?(m[5], m[6])

    inicio = minutes_of_day(m[1], m[2], m[3])
    fin = minutes_of_day(m[4], m[5], m[6])
    fin += MAX_MINUTES if fin <= inicio
    fin - inicio
  end

  def clock?(minutes, suffix)
    minutes.present? || suffix.to_s.match?(/[ap]/i)
  end

  def minutes_of_day(hour, minutes, suffix)
    hora = hour.to_i % 12
    hora += 12 if suffix.to_s.downcase.start_with?('p')
    hora = hour.to_i if suffix.blank? || !suffix.to_s.match?(/[ap]/i)
    (hora * 60) + minutes.to_i
  end
end
