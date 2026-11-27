# CrmZeus Q4.0 — importe con letra, como `config.numeroALetras` de master2 (`crm/config.js`):
#   Crm::AmountInWords.new(1200.5, 'PESOS/M.N.').to_s  # => "Un mil doscientos PESOS 50/100 M.N."
# El número va en minúsculas con la primera en mayúscula y respeta las formas de master2 («UN MIL»,
# «VEINTIUN», «UN MILLÓN DE» cuando son millones cerrados). El texto de la moneda
# (`crm_currencies.amount_in_words`) se parte por «/»: lo de antes va antes de « NN/100» y lo de después,
# al final; sin «/» todo va antes. master2 colapsa los espacios dobles una vez; aquí se colapsan todos.
class Crm::AmountInWords
  UNITS = %w[_ UN DOS TRES CUATRO CINCO SEIS SIETE OCHO NUEVE].freeze
  TEENS = %w[DIEZ ONCE DOCE TRECE CATORCE QUINCE].freeze
  TENS = %w[_ _ _ TREINTA CUARENTA CINCUENTA SESENTA SETENTA OCHENTA NOVENTA].freeze
  HUNDREDS = %w[_ _ DOSCIENTOS TRESCIENTOS CUATROCIENTOS QUINIENTOS SEISCIENTOS SETECIENTOS OCHOCIENTOS
                NOVECIENTOS].freeze

  def initialize(amount, currency_text = nil)
    @amount = BigDecimal(amount.to_s).round(2)
    @currency, @suffix = currency_text.to_s.split('/', 2).map(&:strip)
  end

  def to_s
    integer = @amount.floor
    cents = ((@amount - integer) * 100).round.to_i
    words = millions(integer.to_i)
    words = 'CERO' if words.strip.empty?
    text = [words.downcase, @currency, format('%02d/100', cents), @suffix].compact_blank.join(' ').squish
    text[0] = text[0].upcase
    text
  end

  private

  def units(num)
    num.zero? ? '' : UNITS[num]
  end

  def tens(num)
    ten, unit = num.divmod(10)
    case ten
    when 0 then units(unit)
    when 1 then unit < 6 ? TEENS[unit] : "DIECI#{units(unit)}"
    when 2 then unit.zero? ? 'VEINTE' : "VEINTI#{units(unit)}"
    else unit.positive? ? "#{TENS[ten]} Y #{units(unit)}" : TENS[ten]
    end
  end

  def hundreds(num)
    hundred, rest = num.divmod(100)
    case hundred
    when 0 then tens(rest)
    when 1 then rest.positive? ? "CIENTO #{tens(rest)}" : 'CIEN'
    else "#{HUNDREDS[hundred]} #{tens(rest)}"
    end
  end

  def section(num, divisor, singular, plural)
    count = num / divisor
    return '' if count.zero?

    count > 1 ? "#{hundreds(count)} #{plural}" : singular
  end

  def thousands(num)
    head = section(num, 1000, 'UN MIL', 'MIL')
    tail = hundreds(num % 1000)
    head.empty? ? tail : "#{head} #{tail}"
  end

  def millions(num)
    closed = (num % 1_000_000).zero? ? ' DE' : ''
    head = section(num, 1_000_000, "UN MILLÓN#{closed}", "MILLONES#{closed}")
    tail = thousands(num % 1_000_000)
    head.empty? ? tail : "#{head} #{tail}"
  end
end
