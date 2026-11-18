# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q0 — cotizaciones (DCDOCTOS_PDV): folio por agente, defaults del cliente, totales en el
# servidor, impuestos y retenciones por partida, kits, validaciones y estatus.
RSpec.describe CrmQuote do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:iva) { account.crm_taxes.find_by!(name: 'IVA 16%') }
  let(:ret_iva) { account.crm_taxes.create!(name: 'Ret. IVA 10.67%', tax_type: :vat_withholding, percent: 10.67) }
  let(:seller) { account.crm_sellers.create!(name: 'Laura', user: agent) }
  let(:credit) do
    account.crm_payment_terms.create!(name: '30 días', installments_attributes: [{ days: 30, percent: 100 }])
  end
  let(:organization) do
    account.crm_organizations.create!(legal_name: 'Aceros del Norte SA', trade_name: 'Aceros', organization_type: :customer,
                                      seller: seller, payment_term: credit, cfdi_use: 'G03')
  end
  let(:screws) { account.crm_articles.create!(name: 'Tornillo 1/2', key: 'TOR-12', catalog_status: :catalogued) }

  before do
    Crm::DefaultCatalogs.ensure!(account)
    account.crm_quote_series.create!(user: agent, series: 'lau', last_number: 124)
  end

  def build_quote(attrs = {})
    quote = account.crm_quotes.new({ organization: organization, created_by: agent, valid_until: 15.days.from_now.to_date,
                                     delivery_date: 7.days.from_now.to_date }.merge(attrs))
    quote.fill_from_organization
  end

  def add_item(quote, attrs = {})
    quote.items.build({ article: screws, quantity: 1, unit_price: 100, tax_ids: [iva.id] }.merge(attrs))
  end

  # Ejemplo del inventario §3.5: IVA 16 % y descuento extra de 2 % por porcentaje.
  def inventory_example
    quote = build_quote(extra_discount_type: :percent, extra_discount_value: 2)
    add_item(quote, quantity: 10, unit_price: 100, discount_percent: 14.5, position: 0)
    add_item(quote, description: 'Rondana', article: nil, quantity: 3, unit_price: 49.99, position: 1)
    quote.save!
    quote
  end

  describe 'alta' do
    it 'toma la serie del agente, los defaults del cliente y calcula los totales como CRMZeus' do
      quote = inventory_example

      expect(quote).to have_attributes(folio: 'LAU000125', series: 'LAU', number: 125, status: 'pending',
                                       seller: seller, payment_term: credit, cfdi_use: 'G03', sat_payment_method: 'PPD',
                                       exchange_rate: 1, quote_date: Time.zone.today)
      expect(quote.currency).to have_attributes(iso_code: 'MXN', is_local: true)
      expect(quote).to have_attributes(subtotal: BigDecimal('1149.97'), discount_total: 145, extra_discount_percent: 2,
                                       extra_discount_amount: BigDecimal('20.10'), net_amount: BigDecimal('984.87'),
                                       tax_total: BigDecimal('157.58'), withholding_total: 0, total: BigDecimal('1142.45'))
      expect(account.crm_quote_series.find_by!(user: agent).last_number).to eq(125)
    end

    it 'copia clave, descripción, unidad e impuesto al cotizar y guarda los importes de cada partida' do
      first = inventory_example.items.first.reload

      expect(first).to have_attributes(key: 'TOR-12', description: 'Tornillo 1/2', gross_amount: 1000, discount_amount: 145,
                                       net_amount: 855, tax_amount: BigDecimal('134.064'))
      expect(first.item_taxes.sole).to have_attributes(tax: iva, name: 'IVA 16%', tax_type: 'vat', percent: 16,
                                                       base_amount: 855, amount: BigDecimal('134.064'))
      iva.update!(percent: 8)
      expect(first.reload.item_taxes.sole.percent).to eq(16)
    end

    it 'suma IVA y retenciones por separado y los resume por impuesto' do
      quote = build_quote
      add_item(quote, unit_price: 1000, tax_ids: [iva.id, ret_iva.id])
      quote.save!

      expect(quote).to have_attributes(net_amount: 1000, tax_total: 160, withholding_total: BigDecimal('106.70'),
                                       total: BigDecimal('1053.30'))
      expect(quote.items.first).to have_attributes(tax_amount: 160, withholding_amount: BigDecimal('106.7'))
      expect(quote.tax_summary.map { |t| [t[:name], t[:base_amount], t[:amount]] })
        .to eq([['IVA 16%', 1000, 160], ['Ret. IVA 10.67%', 1000, BigDecimal('106.7')]])
    end

    it 'guarda los impuestos del documento (IMPUESTOS_DCDOCTOS_PDV) con netos y brutos, y quita los que ya no van' do
      quote = build_quote(extra_discount_value: 10)
      add_item(quote, quantity: 2, unit_price: 500, discount_percent: 20, tax_ids: [iva.id, ret_iva.id])
      add_item(quote, unit_price: 100, tax_ids: [iva.id])
      quote.save!

      item_tax = quote.items.first.item_taxes.find_by!(tax: iva)
      expect(item_tax).to have_attributes(base_amount: 800, gross_base_amount: 1000, amount: BigDecimal('115.2'),
                                          gross_amount: 144)
      expect(quote.taxes.reload.map { |t| [t.name, t.position, t.base_amount, t.gross_base_amount, t.amount, t.gross_amount] })
        .to eq([['IVA 16%', 0, 900, 1100, BigDecimal('129.6'), BigDecimal('158.4')],
                ['Ret. IVA 10.67%', 1, 800, 1000, BigDecimal('76.824'), BigDecimal('96.03')]])

      quote.items.first.tax_ids = [iva.id]
      quote.save!
      expect(quote.taxes.reload.map(&:name)).to eq(['IVA 16%'])
      expect(CrmQuoteTax.where(quote: quote).count).to eq(1)
    end

    it 'con descuento extra por importe baja los impuestos en la misma proporción' do
      quote = build_quote(extra_discount_type: :amount, extra_discount_value: 100)
      add_item(quote, unit_price: 1000)
      quote.save!

      expect(quote).to have_attributes(extra_discount_amount: 100, extra_discount_percent: 10, net_amount: 900,
                                       tax_total: 144, total: 1044)
    end

    it 'los componentes de un kit no suman: el precio lo lleva el renglón del kit' do
      quote = build_quote
      kit = add_item(quote, description: 'Kit de seguridad', article: nil, role: :kit, quantity: 2, unit_price: 500)
      quote.items.build(description: 'Casco', role: :component, parent_item: kit, quantity: 2, unit_price: 80, tax_ids: [iva.id])
      quote.save!

      expect(quote).to have_attributes(subtotal: 1000, tax_total: 160, total: 1160)
      expect(quote.items.find(&:role_component?)).to have_attributes(net_amount: 0, tax_amount: 0, parent_item: kit)
    end

    it 'el siguiente folio sigue la serie y se brinca uno que ya exista' do
      inventory_example
      account.crm_quote_series.find_by!(user: agent).update!(last_number: 124)
      second = build_quote
      add_item(second)
      second.save!

      expect(second.folio).to eq('LAU000126')
    end

    it 'no deja cotizar a un agente sin serie de folios' do
      quote = build_quote(created_by: create(:user, account: account, role: :agent))
      add_item(quote)

      expect(quote).not_to be_valid
      expect(quote.errors[:base]).to include('El agente no tiene serie de folios para cotizar')
    end

    it 'la moneda extranjera usa su tipo de cambio fijo; la local siempre 1' do
      dollar = account.crm_currencies.create!(name: 'Dólar', iso_code: 'USD', fixed_exchange_rate: 18.25)
      organization.update!(currency: dollar)

      expect(build_quote.exchange_rate).to eq(BigDecimal('18.25'))
    end
  end

  describe 'vendedor por omisión (setOrg de master2)' do
    let(:pedro) { account.crm_sellers.create!(name: 'Pedro') }
    let(:house) { account.crm_sellers.create!(name: 'Mostrador', is_default: true) }

    it 'primero el ligado al agente que cotiza, aunque la organización tenga otro' do
      organization.update!(seller: pedro)

      expect(build_quote.seller).to eq(seller)
    end

    it 'si el agente no es vendedor, el de la organización y luego el predeterminado' do
      organization.update!(seller: pedro)
      seller.update!(user: nil)
      expect(build_quote.seller).to eq(pedro)

      house
      organization.update!(seller: nil)
      expect(build_quote.seller).to eq(house)
    end

    it 'si la organización respeta vendedor, el suyo y no acepta otro' do
      organization.update!(seller: pedro, respect_seller: true)
      expect(build_quote.seller).to eq(pedro)

      quote = add_item(build_quote(seller: seller)).quote
      expect(quote).not_to be_valid
      expect(quote.errors[:seller]).to include(CrmQuote::SELLER_RESPECTED_MESSAGE)
    end
  end

  describe 'validaciones' do
    it 'pide vigencia, uso CFDI, vendedor, condición de pago y al menos una partida' do
      organization.update!(seller: nil, payment_term: nil, cfdi_use: nil)
      seller.update!(user: nil)
      quote = build_quote(valid_until: nil, delivery_date: nil)

      expect(quote).not_to be_valid
      expect(quote.errors.attribute_names).to include(:valid_until, :cfdi_use, :seller, :payment_term, :items)
      expect(quote.errors.attribute_names).not_to include(:delivery_date)
    end

    it 'pide la fecha de entrega solo si la cuenta lo tiene activado (VALIDAR_FECHA_ENTREGA)' do
      account.create_crm_setting!(require_delivery_date: true)
      quote = add_item(build_quote(delivery_date: nil)).quote

      expect(quote).not_to be_valid
      expect(quote.errors.attribute_names).to eq([:delivery_date])
    end

    it 'rechaza un contacto no ligado, un consignatario de otra organización e impuestos ajenos' do
      other = account.crm_organizations.create!(legal_name: 'Otra SA', trade_name: 'Otra', organization_type: :customer)
      foreign_tax = create(:account).crm_taxes.create!(name: 'IVA ajeno', tax_type: :vat, percent: 16)
      quote = build_quote(contact: create(:contact, account: account),
                          shipping_address: other.consignees.create!(consignee_name: 'Bodega', street: 'Calle 5'))
      item = add_item(quote, tax_ids: [iva.id, foreign_tax.id])

      expect(quote).not_to be_valid
      expect(quote.errors.attribute_names).to include(:contact, :shipping_address)
      expect(item.errors[:tax_ids]).to include('no pertenecen a la cuenta')
    end

    it 'un prospecto no lleva consignatario; la vigencia no va antes de la fecha; la OC pide fecha' do
      organization.update!(organization_type: :prospect)
      quote = build_quote(shipping_address: organization.consignees.create!(consignee_name: 'Bodega', street: 'Calle 5'),
                          valid_until: Time.zone.yesterday, purchase_order: 'OC-55')
      add_item(quote)

      expect(quote).not_to be_valid
      expect(quote.shipping_address).to be_nil
      expect(quote.errors.attribute_names).to include(:valid_until, :purchase_order_date)
    end
  end

  describe 'estatus' do
    let(:quote) { inventory_example }

    it 'sigue las transiciones de CRMZeus y guarda quién y cuándo' do
      quote.change_status!(:won, agent)
      expect(quote.reload).to have_attributes(status: 'won', status_changed_by: agent)
      expect(quote.status_changed_at).to be_present

      expect { quote.change_status!(:pending, agent) }.to raise_error(ActiveRecord::RecordInvalid, /Ganada a Pendiente/)
      quote.change_status!(:lost, agent)
      quote.change_status!(:pending, agent)
      expect(quote.reload.status).to eq('pending')
    end

    it 'solo se edita en Pendiente' do
      quote.change_status!(:cancelled, agent)

      expect(quote.update(footer_notes: 'otra')).to be(false)
      expect(quote.errors[:base].first).to include('Solo se puede editar una cotización Pendiente')
      quote.reload.items.to_a.first.quantity = 99 # con la asociación cargada: si no, `first` consulta aparte
      expect(quote.save).to be(false)
    end

    it 'en Pendiente se edita y recalcula; quitar un impuesto lo borra de la partida' do
      item = quote.items.first
      item.tax_ids = []
      quote.save!

      expect(item.reload.item_taxes).to be_empty
      expect(quote.reload.tax_total).to eq(BigDecimal('23.52'))
    end
  end

  it 'una organización con cotizaciones no se borra' do
    inventory_example

    expect(organization.destroy).to be(false)
    expect(organization.errors[:base]).to be_present
  end
end
