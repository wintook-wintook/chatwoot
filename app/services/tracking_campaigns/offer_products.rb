# frozen_string_literal: true

# Campaña con IA · Ofrecer — los productos del Catálogo que se ofrecen, con su precio de promoción, y la vigencia.
#
#   brief['products']    = [{ 'catalog_item_id' => 12, 'promo_price' => '1800.0' }]   (sin promo_price: su precio normal)
#   brief['valid_until'] = '2026-11-30'   la promoción vale hasta ese día (hora de México); la campaña termina ese día
#
# El precio de promoción es como el del Catálogo (si el producto tiene «El precio ya incluye el impuesto», también).
# Lo usan: lo que sabe la IA (lines), la cotización que arma la IA (promo_price: Motor2::Skills::Quote) y el fin de la
# campaña (ends_at). Vencida la vigencia, la cotización vuelve al precio normal y la IA dice que ya terminó.
module TrackingCampaigns::OfferProducts
  MAX = 10
  ZONE = 'America/Mexico_City'

  module_function

  def sanitize(raw)
    rows = Array(raw).first(MAX).filter_map { |row| clean_row(row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h) }
    rows.uniq { |row| row['catalog_item_id'] }
  end

  def clean_row(row)
    id = row['catalog_item_id'].to_i
    return unless id.positive?

    price = row['promo_price'].to_s.delete(',$ ').presence
    { 'catalog_item_id' => id, 'promo_price' => (price.to_d.round(2).to_s('F') if price&.match?(/\A\d+(\.\d+)?\z/)) }.compact
  end

  def valid_until(raw)
    Date.iso8601(raw.to_s).iso8601
  rescue ArgumentError, TypeError
    nil
  end

  # El último momento de la vigencia (fin del día, hora de México).
  def ends_at(date_text)
    date = valid_until(date_text)
    date && Time.find_zone(ZONE).parse(date).end_of_day
  end

  def active?(date_text, now = Time.current)
    limit = ends_at(date_text)
    limit.nil? || now <= limit
  end

  # El precio de promoción de ese producto mientras dure la vigencia (nil si no tiene o ya venció).
  def promo_price(products, date_text, catalog_item, now = Time.current)
    return unless catalog_item && active?(date_text, now)

    row = Array(products).find { |r| r['catalog_item_id'].to_i == catalog_item.id }
    row && row['promo_price'].present? ? row['promo_price'].to_d : nil
  end

  # Para lo que sabe la IA: «- Mantenimiento preventivo: $2,600.00 MXN → precio de promoción $1,800.00 MXN».
  def lines(account, products, date_text, now = Time.current)
    items = account.catalog_items.where(id: Array(products).pluck('catalog_item_id')).index_by(&:id)
    on = active?(date_text, now)
    Array(products).filter_map do |row|
      item = items[row['catalog_item_id'].to_i]
      line(item, on && row['promo_price'].presence) if item
    end
  end

  def line(item, promo)
    price = money(item.price, item.currency)
    text = promo ? "#{price} → precio de promoción #{money(promo, item.currency)}" : price
    "- #{item.name}: #{text}#{" (#{item.description.to_s.squish.first(160)})" if item.description.present?}"
  end

  def vigencia_line(date_text, now = Time.current)
    date = valid_until(date_text)
    return unless date

    text = "#{date.to_date.day} de #{TrackingCampaigns::ContactFacts::MONTHS[date.to_date.month - 1]}"
    return "- Vigencia: la promoción vale hasta el #{text}." if active?(date_text, now)

    "- LA PROMOCIÓN YA TERMINÓ (venció el #{text}): si pregunta, dile con amabilidad que ya terminó; no ofrezcas el " \
      'precio de promoción, solo el precio normal.'
  end

  def money(amount, currency)
    "$#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', amount.to_d))} #{currency.presence || 'MXN'}"
  end
end
