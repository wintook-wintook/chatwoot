# Cotizaciones › Formatos — limpia lo que llega del diseñador antes de guardarlo en quote_formats.settings: solo
# las llaves conocidas, colores #rrggbb, listas dentro de sus opciones y textos con tope.
module Quotes::FormatSettings
  TEXT_MAX = 3000
  COLOR = /\A#\h{6}\z/
  BOOL = ActiveModel::Type::Boolean.new

  module_function

  def clean(raw)
    raw = raw.deep_stringify_keys
    {
      'brand' => brand(raw['brand']), 'blocks' => blocks(raw['blocks']),
      'header' => header(raw['header']), 'client' => { 'fields' => pick(raw.dig('client', 'fields'), QuoteFormat::CLIENT_FIELDS) },
      'items' => items(raw['items']), 'totals' => flags(raw['totals'], %w[tax_breakdown withholdings amount_in_words]),
      'signatures' => flags(raw['signatures'], %w[seller client])
    }.merge(texts(raw)).transform_values { |value| value.is_a?(Hash) ? value.compact : value }.compact_blank
  end

  def brand(raw)
    return nil unless raw.is_a?(Hash)

    { 'color' => (raw['color'] if COLOR.match?(raw['color'].to_s)),
      'font' => (raw['font'] if QuoteFormat::FONTS.include?(raw['font'])),
      'paper' => (raw['paper'] if %w[letter a4].include?(raw['paper'])),
      'logo_position' => (raw['logo_position'] if %w[left center right].include?(raw['logo_position'])),
      'logo_size' => (raw['logo_size'] if %w[small medium large].include?(raw['logo_size'])) }.compact
  end

  def blocks(raw)
    return nil unless raw.is_a?(Array)

    raw.filter_map { |b| { 'key' => b['key'], 'on' => BOOL.cast(b['on']) || false } if b.is_a?(Hash) && QuoteFormat::BLOCKS.include?(b['key']) }
       .uniq { |b| b['key'] }
  end

  def header(raw)
    return nil unless raw.is_a?(Hash)

    company = raw['company'].is_a?(Hash) ? Quotes::Company.clean(raw['company']) : {}
    { 'fields' => pick(raw['fields'], QuoteFormat::COMPANY_FIELDS), 'company' => company }.compact
  end

  def items(raw)
    return nil unless raw.is_a?(Hash)

    { 'columns' => pick(raw['columns'], QuoteFormat::ITEM_COLUMNS), 'prices_with_tax' => BOOL.cast(raw['prices_with_tax']) || false }
  end

  def flags(raw, keys)
    return nil unless raw.is_a?(Hash)

    keys.index_with { |key| BOOL.cast(raw[key]) || false }
  end

  def texts(raw)
    %w[intro terms bank footer].index_with do |key|
      text = raw.dig(key, 'text')
      { 'text' => text.to_s.strip.first(TEXT_MAX) } unless text.nil?
    end.compact
  end

  # nil = no vino (se queda el de fábrica); [] = ninguno.
  def pick(values, allowed)
    return nil unless values.is_a?(Array)

    values.map(&:to_s) & allowed
  end
end
