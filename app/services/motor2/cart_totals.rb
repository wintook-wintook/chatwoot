# frozen_string_literal: true

# Motor 2.0 — las cuentas de «su cuenta» (Motor2::Skills::QuoteCart), hechas por el código como en la cotización:
#   - producto con «el precio ya incluye el impuesto» → su precio es el final (no se le suma nada);
#   - si no → se le suma su impuesto (subtotal + IVA = total).
# Precio de promoción de la campaña (Ofrecer) si lo tiene.
#
#   Motor2::CartTotals.new([[catalog_item, 2], …], promo: ->(item) { nil }).call
#   → { partidas: [{ producto:, cantidad:, precio:, importe: }], subtotal:, impuesto:, total:, iva_incluido: }
class Motor2::CartTotals
  def initialize(items, promo: ->(_item) {})
    @items = items
    @promo = promo
  end

  def call
    lines = @items.map { |(item, qty)| line(item, qty) }
    subtotal = lines.sum { |l| l[:importe] }
    tax = @items.zip(lines).sum { |((item, _), l)| item.price_includes_tax? ? 0 : (l[:importe] * item.quote_tax_percent.to_d / 100).round(2) }
    { partidas: lines.map { |l| l.merge(importe: l[:importe].to_f) }, subtotal: subtotal.to_f, impuesto: tax.to_f, total: (subtotal + tax).to_f,
      iva_incluido: @items.any? { |(item, _)| item.price_includes_tax? } }
  end

  private

  def line(item, qty)
    price = (@promo.call(item) || item.price).to_d
    { producto: item.name, cantidad: qty, precio: price.to_f, importe: (price * qty.to_d).round(2) }
  end
end
