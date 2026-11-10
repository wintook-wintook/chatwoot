# frozen_string_literal: true

# CrmZeus Q0 — totales de una cotización igual que CRMZeus (traído de feat/cotizador F2, 9abfdc7d).
# Tienen que salir idénticos al centavo a los del navegador de CRMZeus:
# `showTotals`, `calcTax` y `addTaxes` (form.js:1708-1835) y `pricesWithTaxes` (config.js:1805-1847).
#
# Por eso se calcula como JavaScript: Float en el mismo orden de operaciones y `toFixed`, que redondea
# half-up sobre el valor binario exacto (1.005 → 1.00). BigDecimal daría 1.01 en esos casos.
#
# Entrada (partidas visibles, sin componentes de kit ni características, en el orden en pantalla):
#   discount:      { type: 'P' | 'I', value: % o importe del descuento extra }
#   freight:, other_charges:
#   items:         [{ quantity:, unit_price:, discounts: [% en cascada], tax_percent:, withholding_percent:,
#                     taxes: [{ id:, percent: }] }]
# Los descuentos de la partida van como CRMZeus los arma al abrir: sin renglones en
# DSCTOS_DCDOCTOS_PDV_DET, uno con PCTJE_DSCTO (contrato §4.1).
class Crm::QuoteCalculator
  def initialize(discount:, items:, freight: 0, other_charges: 0)
    @percent_discount = discount[:type].to_s != 'I'
    # form.js:1738 — el +0.001 corrige el redondeo de toFixed (2.675 → 2.68).
    @extra = fixed(number(discount[:value]) + 0.001, 2)
    @items = items
    @freight = number(freight)
    @other_charges = number(other_charges)
  end

  def call
    subtotal = discounts = taxes = withholdings = 0.0
    items = @items.map do |item|
      line = line_amounts(item)
      subtotal = fixed(subtotal + line[:gross], 2)
      discounts += line[:discount]
      taxes += line[:tax]
      withholdings += line[:withholding]
      line
    end
    totals(subtotal, discounts, fixed(taxes, 2), fixed(withholdings, 2)).merge(
      document_taxes: document_taxes(items), items: items.map { |l| present_line(l) }
    )
  end

  private

  def line_amounts(item)
    quantity = number(item[:quantity])
    price = number(item[:unit_price])
    cascade = cascade(price, quantity, Array(item[:discounts]))
    gross = fixed(quantity * price, 2)
    discount = fixed(gross * cascade[:percent] / 100, 2)
    net = gross - discount
    { gross: gross, discount: discount, net: net, discount_percent: cascade[:percent], discounts: cascade[:rows],
      tax: tax(net, item[:tax_percent]), withholding: tax(net, item[:withholding_percent]),
      taxes: Array(item[:taxes]).map { |t| line_tax(t, net, gross) } }
  end

  # pricesWithTaxes: cada descuento se aplica sobre el precio unitario que dejó el anterior; con más de
  # uno, el % efectivo es el descuento acumulado sobre el precio.
  def cascade(price, quantity, percents)
    remaining = price
    unit_discount = 0.0
    percent = 0.0
    rows = percents.map { |p| number(p) }.map do |p|
      next { percent: p, amount: 0.0 } unless p.positive?

      percent = p
      amount = fixed(remaining * p / 100 * quantity, 2)
      cut = fixed(remaining * p / 100, 2)
      unit_discount += cut
      remaining -= cut
      { percent: p, amount: amount }
    end
    percent = unit_discount * 100 / price if rows.count { |r| r[:percent].positive? } > 1
    { percent: fixed(percent, 6), rows: rows }
  end

  def line_tax(tax, net, gross)
    percent = number(tax[:percent])
    { id: tax[:id], percent: percent, net_base: fixed(net, 2), gross_base: gross,
      amount: tax(net, percent), gross_amount: tax(gross, percent) }
  end

  # calcTax: con descuento extra por porcentaje, el impuesto se calcula sobre el importe ya descontado.
  def tax(amount, percent)
    rate = number(percent) / 100
    value = @percent_discount ? (amount - (amount * (@extra / 100))) * rate : amount * rate
    fixed(value, 6)
  end

  def totals(subtotal, discounts, taxes, withholdings)
    extra = @percent_discount ? (subtotal - discounts) * @extra / 100 : @extra
    net = subtotal - discounts - extra
    taxes, withholdings = [taxes, withholdings].map { |v| v - ((share(net, extra) * v) / 100) } unless @percent_discount
    {
      subtotal: dec(fixed(subtotal, 2)), item_discounts: dec(fixed(discounts, 2)), discount: extra_discount(net, extra)
    }.merge(charges(net, taxes, withholdings))
  end

  def charges(net, taxes, withholdings)
    { net: dec(fixed(net, 2)), taxes: dec(fixed(taxes, 2)), withholdings: dec(fixed(withholdings, 2)),
      freight: dec(@freight), other_charges: dec(@other_charges),
      total: dec(fixed(net + @freight + @other_charges + taxes - withholdings, 2)) }
  end

  # Descuento por importe: impuestos y retenciones bajan en la misma proporción que el importe.
  def share(net, extra)
    (net + extra).positive? ? (extra * 100) / (net + extra) : 0.0
  end

  # upSert (controller.js:44-46): DSCTO_PCTJE es el % capturado o, por importe, el que representa sobre el
  # neto ya redondeado; DSCTO_IMPORTE es el importe redondeado.
  def extra_discount(net, extra)
    percent = @percent_discount ? @extra : (extra * 100) / (fixed(net, 2) + extra)
    percent = 0.0 unless percent.finite?
    { type: @percent_discount ? 'P' : 'I', percent: dec(percent), amount: dec(fixed(extra, 2)) }
  end

  # addTaxes: un renglón por impuesto, en el orden en que aparece en las partidas.
  def document_taxes(lines)
    lines.flat_map { |l| l[:taxes] }.group_by { |t| t[:id] }.map do |id, rows|
      { id: id, percent: dec(rows.first[:percent]),
        net_base: sum(rows, :net_base, 2), gross_base: sum(rows, :gross_base, 2),
        amount: sum(rows, :amount, 6), gross_amount: sum(rows, :gross_amount, 6) }
    end
  end

  # Acumulado redondeando en cada paso, como addTaxes.
  def sum(rows, key, decimals)
    dec(rows.reduce(0.0) { |total, row| fixed(total + row[key], decimals) })
  end

  def present_line(line)
    { discount_percent: dec(line[:discount_percent]), net: dec(fixed(line[:net], 2)),
      gross: dec(line[:gross]), discount: dec(line[:discount]),
      discounts: line[:discounts].map { |d| { percent: dec(d[:percent]), amount: dec(d[:amount]) } },
      taxes: line[:taxes].map { |t| t.to_h { |k, v| [k, k == :id ? v : dec(v)] } } }
  end

  # Number(`${value}`) de JS: nil, '' y NaN valen 0.
  def number(value)
    float = Float(value.to_s.delete(',$').presence || 0, exception: false) || 0.0
    float.finite? ? float : 0.0
  end

  # (value).toFixed(decimals) * 1
  def fixed(value, decimals)
    return 0.0 unless value.finite?

    value.to_r.round(decimals, half: :up).to_f
  end

  # El Float más corto que lo representa; al volver a Float es el mismo double que tendría el navegador.
  def dec(value)
    BigDecimal(value.to_s)
  end
end
