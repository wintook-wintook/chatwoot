# frozen_string_literal: true

# Motor 2.0 — las cuentas de «su cuenta» (Motor2::Skills::QuoteCart), hechas por el código como en la cotización:
#   - producto con «el precio ya incluye el impuesto» → su precio es el final (no se le suma nada);
#   - si no → se le suma su impuesto (subtotal + IVA = total).
# Precio de promoción de la campaña (Ofrecer) si lo tiene.
#
#   Motor2::CartTotals.new([[catalog_item, 2], …], promo: ->(item) { nil }).call
#   → { partidas: [{ producto:, cantidad:, precio:, importe: }], subtotal: (sin IVA), impuesto:, total:, tasa:, iva_incluido: }
class Motor2::CartTotals
  # La lista y el desglose (subtotal sin IVA, IVA y total), para la cuenta del chat y la confirmación de la cita.
  def self.text(totals)
    lines = totals[:partidas].map { |l| "• #{l[:producto]} ×#{qty(l[:cantidad])} — #{money(l[:importe])}" }
    rate = totals[:tasa] ? " (#{qty(totals[:tasa])} %)" : ''
    lines.push("Subtotal: #{money(totals[:subtotal])}", "IVA#{rate}: #{money(totals[:impuesto])}", "Total: #{money(totals[:total])}")
    lines.join("\n")
  end

  def self.money(value) = "$#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', value.to_f).delete_suffix('.00'))}"

  def self.qty(value) = value.to_f.round(2) == value.to_f.round ? value.to_f.round : value.to_f.round(2)

  def initialize(items, promo: ->(_item) {})
    @items = items
    @promo = promo
  end

  # subtotal sin IVA, IVA y total. Con «el precio ya incluye el impuesto», el total es la suma de precios y el IVA es lo
  # que va dentro (para desglosarlo); sin incluir, se suma.
  def call
    lines = @items.map { |(item, qty)| line(item, qty) }
    total = lines.sum { |l| l[:importe] + l[:iva_extra] }
    subtotal = lines.sum { |l| l[:neto] }
    { partidas: lines.map { |l| l.slice(:producto, :cantidad, :precio).merge(importe: l[:importe].to_f) },
      subtotal: subtotal.to_f, impuesto: (total - subtotal).to_f, total: total.to_f, tasa: rate,
      iva_incluido: @items.any? { |(item, _)| item.price_includes_tax? } }
  end

  # La tasa (si todos llevan la misma; si no, nil).
  def rate
    rates = @items.map { |(item, _)| item.quote_tax_percent.to_f }.uniq
    rates.one? ? rates.first : nil
  end

  private

  def line(item, qty)
    price = (@promo.call(item) || item.price).to_d
    amount = (price * qty.to_d).round(2)
    pct = item.quote_tax_percent.to_d / 100
    net = item.price_includes_tax? ? (amount / (1 + pct)).round(2) : amount
    { producto: item.name, cantidad: qty, precio: price.to_f, importe: amount, neto: net,
      iva_extra: item.price_includes_tax? ? 0 : (amount * pct).round(2) }
  end
end
