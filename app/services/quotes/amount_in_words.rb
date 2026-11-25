# Cotizaciones › Formatos — el total con letra, como en las facturas: «MIL NOVECIENTOS CINCUENTA Y TRES PESOS 33/100 M.N.»
#
#   Quotes::AmountInWords.call(1953.33, 'MXN') → 'MIL NOVECIENTOS CINCUENTA Y TRES PESOS 33/100 M.N.'
#   Quotes::AmountInWords.call(10, 'USD')      → 'DIEZ DÓLARES 00/100 USD'
module Quotes::AmountInWords
  UNITS = %w[CERO UN DOS TRES CUATRO CINCO SEIS SIETE OCHO NUEVE DIEZ ONCE DOCE TRECE CATORCE QUINCE DIECISÉIS
             DIECISIETE DIECIOCHO DIECINUEVE VEINTE VEINTIÚN VEINTIDÓS VEINTITRÉS VEINTICUATRO VEINTICINCO VEINTISÉIS
             VEINTISIETE VEINTIOCHO VEINTINUEVE].freeze
  TENS = %w[_ _ _ TREINTA CUARENTA CINCUENTA SESENTA SETENTA OCHENTA NOVENTA].freeze
  HUNDREDS = %w[_ CIENTO DOSCIENTOS TRESCIENTOS CUATROCIENTOS QUINIENTOS SEISCIENTOS SETECIENTOS OCHOCIENTOS
                NOVECIENTOS].freeze
  CURRENCIES = { 'MXN' => %w[PESO PESOS M.N.], 'USD' => %w[DÓLAR DÓLARES USD], 'EUR' => %w[EURO EUROS EUR] }.freeze

  module_function

  def call(amount, currency = 'MXN')
    amount = amount.to_d.round(2)
    integer = amount.to_i
    cents = ((amount - integer) * 100).round.to_i
    one, many, suffix = CURRENCIES.fetch(currency.to_s.upcase) { [currency, currency, currency] }
    unit = integer == 1 ? one : many
    unit = "DE #{unit}" if integer.positive? && (integer % 1_000_000).zero?
    "#{words(integer)} #{unit} #{format('%02d', cents)}/100 #{suffix}".squish
  end

  def words(number)
    return 'CERO' if number.zero?

    millions, rest = number.divmod(1_000_000)
    thousands, units = rest.divmod(1000)
    [millions_words(millions), thousands_words(thousands), (below_thousand(units) if units.positive?)].compact.join(' ')
  end

  def millions_words(millions)
    return if millions.zero?

    millions == 1 ? 'UN MILLÓN' : "#{words(millions)} MILLONES"
  end

  def thousands_words(thousands)
    return if thousands.zero?

    thousands == 1 ? 'MIL' : "#{below_thousand(thousands)} MIL"
  end

  def below_thousand(number)
    return 'CIEN' if number == 100

    hundreds, rest = number.divmod(100)
    [(HUNDREDS[hundreds] if hundreds.positive?), (below_hundred(rest) if rest.positive?)].compact.join(' ')
  end

  def below_hundred(number)
    return UNITS[number] if number < 30

    tens, unit = number.divmod(10)
    unit.zero? ? TENS[tens] : "#{TENS[tens]} Y #{UNITS[unit]}"
  end
end
