# Cotizaciones › Formatos — arma lo que se ve en el documento de una cotización con su formato. Lo usan la liga
# del cliente (public/quotes/show), la vista previa del diseñador y el PDF (Quotes::Pdf), con la misma vista
# quotes/_document (solo tablas y CSS sencillo: así sale igual en el navegador y en wkhtmltopdf).
#
#   doc = Quotes::Document.new(quote, format: nil, inline_images: false)
#   doc.blocks → %w[header client items …] (los prendidos, en orden) · doc.rows · doc.totals · doc.company …
# inline_images: el logo y las fotos van dentro del HTML (data:) para el PDF; si no, con su URL.
class Quotes::Document
  VARIABLES = %w[cliente empresa_cliente folio vendedor vigencia empresa].freeze
  LOGO_SIZES = { 'small' => 40, 'medium' => 64, 'large' => 96 }.freeze

  attr_reader :quote, :format

  def initialize(quote, format: nil, inline_images: false)
    @quote = quote
    @format = format || QuoteFormat.for(quote)
    @inline = inline_images
  end

  def config = @format.config
  def brand = config['brand']
  def blocks = config['blocks'].select { |b| b['on'] }.pluck('key')
  def logo_height = LOGO_SIZES.fetch(brand['logo_size'], 64)
  def company = @company ||= Quotes::Company.for(@quote.account, @format)
  def company_fields = config.dig('header', 'fields').select { |key| company[key].present? }
  def columns = config.dig('items', 'columns')
  def column?(key) = columns.include?(key)
  def prices_with_tax? = config.dig('items', 'prices_with_tax')
  def option?(block, key) = config.dig(block, key) ? true : false

  def logo_src
    image_src(Quotes::Company.logo(@quote.account, @format))
  end

  def date = (@quote.created_at || Time.current).to_date
  def folio = @quote.number ? @quote.folio : 'COT-0000'

  # Los datos del cliente que pide el formato y que tiene.
  def client_rows
    contact = @quote.contact
    organization = @quote.organization || contact&.organization
    values = { 'name' => contact&.name, 'organization' => organization&.name, 'tax_id' => organization&.tax_id,
               'email' => contact&.email, 'phone' => contact&.phone_number }
    config.dig('client', 'fields').filter_map { |key| [key, values[key]] if values[key].present? }
  end

  def rows
    @rows ||= @quote.items.map { |item| row(item) }
  end

  def totals
    @totals ||= begin
      items = @quote.items.to_a
      gross = items.sum { |i| i.quantity.to_d * i.unit_price.to_d }
      net = items.sum(&:net_amount)
      tax = items.sum(&:tax_amount)
      withheld = @quote.apply_withholdings? ? items.sum(&:withholding_amount) : 0
      { subtotal: gross.round(2), discount: (gross - net).round(2), tax: tax.round(2), withheld: withheld.round(2),
        total: (net + tax - withheld).round(2), taxes: tax_lines(items), withholdings: withholding_lines(items) }
    end
  end

  def amount_in_words = Quotes::AmountInWords.call(totals[:total], @quote.currency)

  # Condiciones: las de la cotización o, si no tiene, las del formato.
  def terms = @quote.terms.presence || fill(config.dig('terms', 'text'))
  def text(block) = fill(config.dig(block, 'text'))

  def money(value) = "#{ActiveSupport::NumberHelper.number_to_currency(value, unit: '$', precision: 2)} #{@quote.currency}"

  private

  # «IVA 16 %» => 160.00 (agrupado por porcentaje).
  def tax_lines(items)
    items.group_by { |i| i.tax_percent.to_d }.filter_map do |percent, group|
      amount = group.sum(&:tax_amount)
      ["IVA #{percent.to_s('F').delete_suffix('.0')} %", amount.round(2)] if amount.positive?
    end
  end

  def withholding_lines(items)
    return [] unless @quote.apply_withholdings?

    items.each_with_object(Hash.new(0)) do |item, sums|
      Array(item.withholdings).each { |row| sums[row['name']] += (item.net_amount * row['percent'].to_d / 100).round(2) }
    end.to_a
  end

  def row(item)
    with_tax = prices_with_tax?
    factor = with_tax ? 1 + (item.tax_percent.to_d / 100) : 1
    catalog = item.catalog_item
    { item: item, sku: catalog&.sku, image: (image_src(catalog&.image, thumb: true) if column?('image')),
      unit_price: (item.unit_price.to_d * factor).round(2), amount: with_tax ? item.net_amount + item.tax_amount : item.net_amount }
  end

  def fill(text)
    return '' if text.blank?

    values = variables
    text.gsub(/\{\{\s*(\w+)\s*\}\}/) { values.fetch(Regexp.last_match(1), '').to_s }
  end

  def variables
    { 'cliente' => @quote.contact&.name, 'empresa_cliente' => (@quote.organization || @quote.contact&.organization)&.name,
      'folio' => folio, 'vendedor' => @quote.assignee&.name, 'vigencia' => @quote.valid_until&.strftime('%d/%m/%Y'),
      'empresa' => company['legal_name'] }
  end

  def image_src(attachment, thumb: false)
    return unless attachment&.attached?

    @inline ? inline(attachment, thumb) : url(attachment)
  rescue StandardError => e
    Rails.logger.warn("[Quotes::Document] imagen: #{e.class}: #{e.message}")
    nil
  end

  def url(attachment)
    host = ENV.fetch('FRONTEND_URL', '')
    "#{host}#{Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)}"
  end

  # Para el PDF: la imagen dentro del HTML (las fotos de producto, reducidas).
  def inline(attachment, thumb)
    blob = attachment.blob
    data = thumb && blob.variable? ? attachment.variant(resize_to_limit: [160, 160]).processed.download : blob.download
    "data:#{blob.content_type};base64,#{Base64.strict_encode64(data)}"
  end
end
