# CrmZeus Q1 — JSON de cotizaciones para la API: renglón de la lista, detalle (con partidas en
# árbol: cada kit lleva sus `components`) y los importes que regresa `calculate`.
module Crm::QuoteJson
  LIST_INCLUDES = %i[organization contact currency created_by].freeze
  DETAIL_INCLUDES = [*LIST_INCLUDES, :seller, :payment_term, :shipping_address, :status_changed_by, :updated_by,
                     { items: :item_taxes }].freeze
  AMOUNTS = %i[subtotal discount_total extra_discount_value extra_discount_percent extra_discount_amount net_amount freight
               other_charges tax_total withholding_total total].freeze
  ITEM_AMOUNTS = %i[quantity unit_price discount_percent gross_amount discount_amount net_amount tax_amount
                    withholding_amount].freeze

  module_function

  def list_item(quote)
    {
      id: quote.id, folio: quote.folio, quote_date: quote.quote_date, valid_until: quote.valid_until,
      status: quote.status, status_label: quote.status_label, status_changed_at: quote.status_changed_at&.to_i,
      organization: organization(quote.organization),
      contact: named(quote.contact), currency: quote.currency&.iso_code, net_amount: quote.net_amount.to_f,
      total: quote.total.to_f, purchase_order: quote.purchase_order, footer_notes: quote.footer_notes,
      created_by: named(quote.created_by), created_by_id: quote.created_by_id, updated_at: quote.updated_at.to_i
    }
  end

  def detail(quote)
    list_item(quote).merge(header(quote)).merge(totals(quote)).merge(
      series: quote.series, number: quote.number, seller: named(quote.seller), payment_term: named(quote.payment_term),
      shipping_address: quote.shipping_address&.slice(:id, :consignee_name)&.merge(full_address: quote.shipping_address.full_address),
      status_changed_by: named(quote.status_changed_by), updated_by: named(quote.updated_by),
      created_at: quote.created_at.to_i, transitions: CrmQuote::TRANSITIONS.fetch(quote.status, [])
    )
  end

  # Cotización sin guardar (`new` y `duplicate`): lo que el formulario necesita para arrancar.
  def draft(quote)
    header(quote).merge(totals(quote)).merge(organization: organization(quote.organization))
  end

  # Lo que ve el formulario mientras se captura: importes sin guardar nada.
  def totals(quote)
    AMOUNTS.index_with { |name| quote[name].to_f }.merge(
      extra_discount_type: quote.extra_discount_type, exchange_rate: quote.exchange_rate.to_f,
      sat_payment_method: quote.sat_payment_method, items: item_tree(quote),
      tax_summary: quote.tax_summary.map { |row| row.merge(row.slice(:percent, :base_amount, :amount).transform_values(&:to_f)) }
    )
  end

  def header(quote)
    quote.slice(:organization_id, :contact_id, :shipping_address_id, :seller_id, :currency_id, :payment_term_id,
                :quote_date, :valid_until, :delivery_date, :cfdi_use, :purchase_order, :purchase_order_date,
                :header_notes, :footer_notes).symbolize_keys
  end

  def item_tree(quote)
    components, tops = quote.items.reject(&:marked_for_destruction?).partition(&:role_component?)
    by_kit = components.group_by(&:parent_item)
    sorted(tops).map do |item|
      row = item_json(item)
      row[:components] = sorted(by_kit.fetch(item, [])).map { |component| item_json(component) } if item.role_kit?
      row
    end
  end

  def sorted(items)
    items.sort_by { |item| [item.position, item.id.to_i] }
  end

  def item_json(item)
    item.slice(:id, :role, :article_id, :key, :description, :unit, :price_list_id, :notes, :extra_notes).symbolize_keys
        .merge(ITEM_AMOUNTS.index_with { |name| item[name].to_f })
        .merge(tax_ids: item.tax_ids, taxes: item.live_taxes.map { |tax| tax_json(tax) })
  end

  def tax_json(tax)
    { tax_id: tax.tax_id, name: tax.name, tax_type: tax.tax_type, percent: tax.percent.to_f,
      base_amount: tax.base_amount.to_f, amount: tax.amount.to_f }
  end

  def organization(org)
    org && { id: org.id, name: org.trade_name, organization_type: org.organization_type, seller_id: org.seller_id,
             respect_seller: org.respect_seller, charge_taxes: org.charge_taxes, withholds_taxes: org.withholds_taxes }
  end

  def named(record)
    record && { id: record.id, name: record.name }
  end
end
