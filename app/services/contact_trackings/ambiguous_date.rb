# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — «EL DÍA LUNES» SIN NÚMERO (pieza 6, 26/09/2026)
# ================================================================================
# «Cotización de una grúa para el día lunes a las 08:00» (OLAM Energy): el motor lo tomaba
# como el próximo lunes y, con hora libre, agendaba en firme sin decir qué lunes. Aquí solo
# se decide SI es ambiguo (sin IA): nombra un día de la semana y ninguna fecha explícita.
#   ambiguo:     «el día lunes», «el martes a las 10», «para el jueves en la tarde»
#   no ambiguo:  «el lunes 28», «lunes 01 de junio», «el 30/06», «martes 30 de junio»
# Qué hace el job con eso: dice la fecha completa y no agenda en firme sin un «sí».
# ================================================================================

module ContactTrackings::AmbiguousDate
  WEEKDAYS = '(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)'
  MONTHS = '(?:ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[a-z]*'
  WEEKDAY_RE = /\b#{WEEKDAYS}\b/i
  EXPLICIT_DATE_RE = %r{\b#{WEEKDAYS}\s+\d{1,2}\b|\b\d{1,2}\s*(?:de\s+|-|/)?\s*#{MONTHS}\b|\b\d{1,2}[/-]\d{1,2}\b}i
  DAY_NAMES = %w[domingo lunes martes miércoles jueves viernes sábado].freeze
  MONTH_NAMES = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  module_function

  def ambiguous?(text)
    texto = text.to_s
    texto.match?(WEEKDAY_RE) && !texto.match?(EXPLICIT_DATE_RE)
  end

  # «Entiendo que es el lunes 28 de septiembre»
  def note(at, timezone)
    dia = at.in_time_zone(timezone)
    "Entiendo que es el #{DAY_NAMES[dia.wday]} #{dia.day} de #{MONTH_NAMES[dia.month - 1]}"
  end
end
