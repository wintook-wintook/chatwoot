# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q0 — totales igual que CRMZeus (traído de feat/cotizador F2). Los casos son cotizaciones
# reales de Microsip con lo que CRMZeus guardó (claudeDev/cotizador_src/casos_prueba__cotizaciones_microsip.json)
# más el ejemplo 3040 del contrato §8. Se compara a la escala de cada columna de Firebird.
RSpec.describe Crm::QuoteCalculator do
  cases = JSON.parse(Rails.root.join('spec/fixtures/files/crm/crmzeus_quote_totals_cases.json').read)

  def calculate(quote)
    described_class.new(
      discount: { type: quote['TIPO_DSCTO'], value: quote['TIPO_DSCTO'] == 'I' ? quote['DSCTO_IMPORTE'] : quote['DSCTO_PCTJE'] },
      freight: quote['FLETES'], other_charges: quote['OTROS_CARGOS'],
      items: quote['PARTIDAS'].map do |p|
        { quantity: p['UNIDADES'], unit_price: p['PRECIO_UNITARIO'], tax_percent: p['PCTJE_IMPUESTO'],
          withholding_percent: p['PCTJE_RET'], discounts: p['DESCUENTOS'].presence || [p['PCTJE_DSCTO']],
          taxes: p['IMPUESTOS'].map { |t| { id: t['IMPUESTO_ID'], percent: t['PCTJE_IMPUESTO'] } } }
      end
    ).call
  end

  def scale(value, decimals)
    BigDecimal(value.to_s).round(decimals)
  end

  cases.each do |quote|
    context "with #{quote['DOCTO_PV_ID']}: #{quote['CASO']}" do
      subject(:result) { calculate(quote) }

      it 'da los totales del encabezado que guardó CRMZeus' do
        expect(result).to include(net: scale(quote['IMPORTE_NETO'], 2), taxes: scale(quote['TOTAL_IMPUESTOS'], 2),
                                  withholdings: scale(quote['TOTAL_RETENCIONES'], 2))
        expect(result[:total]).to eq(result[:net] + result[:freight] + result[:other_charges] + result[:taxes] -
                                     result[:withholdings])
        expect(result[:discount]).to include(type: quote['TIPO_DSCTO'], amount: scale(quote['DSCTO_IMPORTE'], 2))
        # 286 guardó 3.33 en una columna de 6 decimales: es de una versión anterior de CRMZeus.
        expect(result[:discount][:percent].round(2)).to eq(scale(quote['DSCTO_PCTJE'], 2))
      end

      it 'da el neto, el % de descuento y los impuestos de cada partida' do
        quote['PARTIDAS'].zip(result[:items]).each do |expected, line|
          expect(line).to include(discount_percent: scale(expected['PCTJE_DSCTO'], 6),
                                  net: scale(expected['PRECIO_TOTAL_NETO'], 2))
          expected['IMPUESTOS'].zip(line[:taxes]).each do |tax, row|
            expect(row).to include(id: tax['IMPUESTO_ID'], net_base: scale(tax['VENTA_NETA'], 2),
                                   gross_base: scale(tax['VENTA_BRUTA'], 2), amount: scale(tax['IMPORTE_IMPUESTO'], 6))
            expect(row[:gross_amount].round(2)).to eq(scale(tax['IMPORTE_IMPUESTO_BRUTO'], 2))
          end
        end
      end

      it 'da los impuestos del documento' do
        expect(result[:document_taxes].map { |t| [t[:id], t[:net_base], t[:gross_base], t[:amount].round(2)] })
          .to eq(quote['IMPUESTOS'].map do |t|
            [t['IMPUESTO_ID'], scale(t['VENTA_NETA'], 2), scale(t['VENTA_BRUTA'], 2), scale(t['IMPORTE_IMPUESTO'], 2)]
          end)
      end
    end
  end

  it 'da el total con fletes y otros cargos del PDF de 3162' do
    expect(calculate(cases.find { |c| c['DOCTO_PV_ID'] == 3162 })).to include(
      subtotal: BigDecimal('26207.46'), item_discounts: BigDecimal('2620.75'), total: BigDecimal('29603.66')
    )
  end

  it 'arma los renglones de descuento de 3040, incluido el de 0 %' do
    lines = calculate(cases.find { |c| c['DOCTO_PV_ID'] == 3040 })[:items]

    expect(lines.pluck(:discounts)).to eq([[{ percent: 28, amount: 28 }], [{ percent: 0, amount: 0 }]])
  end

  it 'redondea como toFixed de JavaScript y no como BigDecimal' do
    # 1.005 en binario es 1.00499999…: el navegador da 1.00.
    result = described_class.new(discount: { type: 'P', value: 0 }, items: [{ quantity: 1, unit_price: 1.005 }]).call

    expect(result[:subtotal]).to eq(BigDecimal('1'))
  end

  it 'aplica el +0.001 al descuento extra antes de redondearlo' do
    result = described_class.new(discount: { type: 'I', value: '2.675' }, items: [{ quantity: 1, unit_price: 100 }]).call

    expect(result[:discount][:amount]).to eq(BigDecimal('2.68'))
    expect(result[:net]).to eq(BigDecimal('97.32'))
  end

  it 'calcula el % efectivo de los descuentos en cascada' do
    result = described_class.new(discount: { type: 'P', value: nil },
                                 items: [{ quantity: 3, unit_price: 99.99, discounts: [10, 5], tax_percent: 16 }]).call
    line = result[:items].first

    # 99.99 → −10.00 = 89.99 → −4.50 = 85.49; 14.50 / 99.99 = 14.501450 %
    expect(line[:discount_percent]).to eq(BigDecimal('14.50145'))
    expect(line[:discounts]).to eq([{ percent: 10, amount: BigDecimal('30') }, { percent: 5, amount: BigDecimal('13.5') }])
    expect(line[:net]).to eq(BigDecimal('256.47'))
  end

  it 'no truena con partidas en cero ni descuento por importe sin neto' do
    result = described_class.new(discount: { type: 'I', value: 10 },
                                 items: [{ quantity: 0, unit_price: 0, discounts: [10, 5] }]).call

    expect(result).to include(net: BigDecimal('-10'), taxes: 0, total: BigDecimal('-10'))
    expect(result[:discount][:percent]).to eq(0)
  end
end
