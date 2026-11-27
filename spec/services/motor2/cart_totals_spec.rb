# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — las cuentas de «su cuenta» las hace el código, con el impuesto de cada producto.
RSpec.describe Motor2::CartTotals do
  let(:account) { create(:account) }
  let(:iva16) { account.tax_rates.find_by(percent: 16, kind: :transfer) }

  it 'precio con IVA incluido: el total es la suma de precios; sin incluir, se suma el IVA' do
    CatalogParameters.ensure!(account)
    included = CatalogItem.create!(account: account, name: 'Manicure', kind: :service, price: 350, price_includes_tax: true, tax_rate: iva16)
    plus_tax = CatalogItem.create!(account: account, name: 'Kit', kind: :product, price: 100, price_includes_tax: false, tax_rate: iva16)

    only_included = described_class.new([[included, 2]]).call
    expect(only_included).to include(total: 700.0, subtotal: 603.45, impuesto: 96.55, iva_incluido: true)
    expect(described_class.text(only_included)).to include('Manicure ×2 — $700', 'Subtotal: $603.45', 'IVA (16 %): $96.55',
                                                           'Total: $700')

    mixed = described_class.new([[included, 1], [plus_tax, 1]]).call
    expect(mixed[:total]).to eq(350.0 + 116.0)
    expect(mixed[:subtotal] + mixed[:impuesto]).to eq(mixed[:total])
  end

  it 'en la cotización, la partida con IVA incluido suma exacto el precio del Catálogo (sin el centavo de redondeo)' do
    CatalogParameters.ensure!(account)
    item = CatalogItem.create!(account: account, name: 'Manicure', kind: :service, price: 350, price_includes_tax: true, tax_rate: iva16)
    line = QuoteItem.new(account: account, catalog_item: item, description: 'Manicure', quantity: 2,
                         unit_price: item.quote_unit_price, tax_percent: item.quote_tax_percent)
    line.valid?
    expect(line.total.to_f).to eq(700.0)
  end
end
