# Cotizaciones — retenciones (Ret. IVA, Ret. ISR…): cada partida guarda las suyas (copia con nombre y porcentaje,
# QuoteItem#withholdings) y la cotización las resta del total solo si apply_withholdings está marcado. Se marca
# solo cuando el cliente es persona moral: el RFC de su organización tiene 12 caracteres (el de persona física, 13).
#
#   Quotes::Withholdings.moral?(organization)          → true / false
#   Quotes::Withholdings.for_contact(contact, org_id)  → si aplica a la cotización de ese cliente
#   Quotes::Withholdings.clean(raw)                     → [{ 'id', 'name', 'percent' }] válidas (máx. 4)
#   Quotes::Withholdings.totals(items, withhold:)       → { net, tax, withheld, total } de partidas en hash (Dali)
module Quotes::Withholdings
  MORAL_RFC = /\A[A-ZÑ&]{3}\d{6}[A-Z\d]{3}\z/
  MAX = 4

  module_function

  def moral?(organization)
    MORAL_RFC.match?(organization&.tax_id.to_s.strip.upcase)
  end

  def for_contact(contact, organization_id = nil)
    organization = Organization.find_by(id: organization_id, account_id: contact&.account_id) if organization_id.present?
    moral?(organization || contact&.organization)
  end

  def clean(raw)
    Array(raw).first(MAX).filter_map do |row|
      row = row.to_h.stringify_keys
      percent = row['percent'].to_d
      next if row['name'].blank? || percent <= 0 || percent > 100

      { 'id' => row['id'].presence&.to_i, 'name' => row['name'].to_s.squish.first(60), 'percent' => percent.round(4).to_f }
    end
  end

  # { net:, tax:, withheld:, total: } igual que Quote#recalculate! (descuento por partida; retenciones solo si
  # withhold). Para partidas que todavía son hashes (la propuesta de Dali).
  def totals(items, withhold: false)
    net = items.sum { |item| item_net(item) }
    tax = items.sum { |item| (item_net(item) * item['tax_percent'].to_d / 100).round(2) }
    withheld = withhold ? items.sum { |item| item_withheld(item) } : 0
    { 'net' => net.to_f, 'tax' => tax.to_f, 'withheld' => withheld.to_f, 'total' => (net + tax - withheld).to_f }
  end

  def item_net(item)
    (item['quantity'].to_d * item['unit_price'].to_d * (1 - (item['discount_percent'].to_d / 100))).round(2)
  end

  def item_withheld(item)
    Array(item['withholdings']).sum { |row| (item_net(item) * row['percent'].to_d / 100).round(2) }
  end
end
