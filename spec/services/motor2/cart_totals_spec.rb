# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — las cuentas de «su cuenta» las hace el código, con el impuesto de cada producto.
RSpec.describe Motor2::CartTotals do
  let(:account) { create(:account) }

  it 'precio con IVA incluido: el total es la suma de precios; sin incluir, se suma el IVA' do
    CatalogParameters.ensure!(account)
    included = CatalogItem.create!(account: account, name: 'Manicure', kind: :service, price: 350, price_includes_tax: true)
    plus_tax = CatalogItem.create!(account: account, name: 'Kit', kind: :product, price: 100, price_includes_tax: false)

    only_included = described_class.new([[included, 2]]).call
    expect(only_included).to include(total: 700.0, impuesto: 0.0, iva_incluido: true)

    mixed = described_class.new([[included, 1], [plus_tax, 1]]).call
    expect(mixed[:subtotal]).to eq(450.0)
    expect(mixed[:impuesto]).to eq((100 * plus_tax.quote_tax_percent / 100).round(2).to_f)
    expect(mixed[:total]).to eq(mixed[:subtotal] + mixed[:impuesto])
  end

  it 'en la cotización, la partida con IVA incluido suma exacto el precio del Catálogo (sin el centavo de redondeo)' do
    CatalogParameters.ensure!(account)
    item = CatalogItem.create!(account: account, name: 'Manicure', kind: :service, price: 350, price_includes_tax: true)
    line = QuoteItem.new(account: account, catalog_item: item, description: 'Manicure', quantity: 2,
                         unit_price: item.quote_unit_price, tax_percent: item.quote_tax_percent)
    line.valid?
    expect(line.total.to_f).to eq(700.0)
  end
end
