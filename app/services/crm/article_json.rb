# CrmZeus A1 — JSON de artículos para la API (lista y detalle).
module Crm::ArticleJson
  LIST_INCLUDES = [:line, :unit, { prices: :price_list }, { image_attachment: :blob }].freeze
  DETAIL_INCLUDES = [:line, :unit, :taxes, :created_by, :updated_by, { prices: %i[price_list currency] },
                     { image_attachment: :blob }].freeze

  module_function

  def list_item(article)
    {
      id: article.id, catalog_status: article.catalog_status, key: article.key, name: article.name,
      status: article.status, is_stockable: article.is_stockable, line: named(article.line),
      unit: article.unit && { id: article.unit.id, name: article.unit.name, sat_key: article.unit.sat_key },
      default_price: default_price(article), image_url: article.image_url, updated_at: article.updated_at.to_i
    }
  end

  def detail(article)
    list_item(article).merge(other_fields(article)).merge(
      cataloged_at: article.cataloged_at&.to_i, created_at: article.created_at.to_i,
      created_by: named(article.created_by), updated_by: named(article.updated_by),
      prices: article.prices.map { |price| price_json(price) },
      tax_ids: article.taxes.map(&:id), taxes: article.taxes.map { |tax| { id: tax.id, name: tax.name } }
    )
  end

  # Pestaña «Otros» + los ids de línea y unidad para el formulario.
  def other_fields(article)
    article.slice(:line_id, :unit_id, :purchase_unit, :notes)
           .merge(purchase_unit_content: article.purchase_unit_content.to_f, unit_weight: article.unit_weight.to_f)
  end

  def price_json(price)
    { id: price.id, price_list_id: price.price_list_id, price_list: price.price_list&.name, price: price.price.to_f,
      currency_id: price.currency_id, currency: price.currency&.iso_code }
  end

  # El de la lista predeterminada (o el primero), para la columna «Precio» de la lista.
  def default_price(article)
    price = article.prices.find { |item| item.price_list&.is_default? } || article.prices.first
    price && { price: price.price.to_f, price_list: price.price_list&.name }
  end

  def named(record)
    record && { id: record.id, name: record.name }
  end
end
