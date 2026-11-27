# CrmZeus Q0 — pone los importes de una cotización y de sus partidas con Crm::QuoteCalculator.
# Corre en cada guardado (before_validation de CrmQuote): el servidor siempre recalcula. Los
# componentes de un kit no tienen importe propio (el precio lo lleva el renglón del kit).
class Crm::QuoteTotals
  def initialize(quote)
    @quote = quote
  end

  def apply
    live = @quote.items.reject(&:marked_for_destruction?)
    live.each(&:prepare)
    priced = @quote.priced_items
    result = calculator(priced).call
    priced.zip(result[:items]).each { |item, line| write_item(item, line) }
    (live - priced).each { |item| clear_item(item) }
    write_quote(result)
    write_document_taxes(result[:document_taxes], priced)
  end

  private

  def calculator(items)
    Crm::QuoteCalculator.new(
      discount: { type: @quote.extra_discount_amount? ? 'I' : 'P', value: @quote.extra_discount_value },
      freight: @quote.freight, other_charges: @quote.other_charges,
      items: items.map { |item| input(item) }
    )
  end

  def input(item)
    taxes = item.live_taxes
    withholdings, charges = taxes.partition(&:withholding?)
    { quantity: item.quantity, unit_price: item.unit_price, discounts: [item.discount_percent],
      tax_percent: charges.sum(&:percent), withholding_percent: withholdings.sum(&:percent),
      taxes: taxes.map { |tax| { id: tax.tax_id, percent: tax.percent } } }
  end

  def write_item(item, line)
    item.assign_attributes(discount_percent: line[:discount_percent], gross_amount: line[:gross],
                           discount_amount: line[:discount], net_amount: line[:net])
    item.live_taxes.zip(line[:taxes]).each do |tax, row|
      tax.assign_attributes(base_amount: row[:net_base], gross_base_amount: row[:gross_base], amount: row[:amount],
                            gross_amount: row[:gross_amount])
    end
    withholdings, charges = item.live_taxes.partition(&:withholding?)
    item.assign_attributes(tax_amount: charges.sum(&:amount), withholding_amount: withholdings.sum(&:amount))
  end

  def clear_item(item)
    item.assign_attributes(gross_amount: 0, discount_amount: 0, net_amount: 0, tax_amount: 0, withholding_amount: 0)
    item.live_taxes.each { |tax| tax.assign_attributes(base_amount: 0, gross_base_amount: 0, amount: 0, gross_amount: 0) }
  end

  # Q3.1 — IMPUESTOS_DCDOCTOS_PDV: un renglón por impuesto (addTaxes); se reusan los que ya había y
  # se quitan los que ya no aparecen en las partidas.
  def write_document_taxes(rows, priced)
    sources = priced.flat_map(&:live_taxes).index_by(&:tax_id)
    existing = @quote.taxes.index_by(&:tax_id)
    rows.each_with_index do |row, position|
      source = sources.fetch(row[:id])
      tax = existing.delete(row[:id]) || @quote.taxes.build
      tax.assign_attributes(account_id: @quote.account_id, tax_id: row[:id], name: source.name, tax_type: source.tax_type,
                            percent: row[:percent], base_amount: row[:net_base], gross_base_amount: row[:gross_base],
                            amount: row[:amount], gross_amount: row[:gross_amount], position: position)
    end
    existing.each_value(&:mark_for_destruction)
  end

  def write_quote(result)
    @quote.assign_attributes(
      subtotal: result[:subtotal], discount_total: result[:item_discounts],
      extra_discount_percent: result[:discount][:percent].round(6), extra_discount_amount: result[:discount][:amount],
      net_amount: result[:net], tax_total: result[:taxes], withholding_total: result[:withholdings], total: result[:total]
    )
  end
end
