# frozen_string_literal: true

# Asistente (Dali) — cotizaciones hablando.
#
#   search_catalog(query)          → productos y servicios del Catálogo con su precio
#   list_quotes(contact_id | organization_id | status) → las cotizaciones que el usuario ve
#   propose_create_quote           → tarjeta con cliente, partidas, moneda, totales y
#                                    oportunidad; al confirmar se crea en borrador
#                                    (Assistant::QuoteRunner, con Quotes::Builder)
#   propose_send_quote(quote_id)   → tarjeta; al confirmar se manda por la conversación más
#                                    reciente del cliente (Quotes::Delivery)
#
# Crear pide Ventas con permiso de escribir y un contacto que el usuario ve. Quien no ve
# montos (Access::Grant#quote_amounts_visible?) no los recibe en las cotizaciones ajenas.
# Se incluye en Assistant::Tools.
module Assistant::QuoteTools
  QUOTE_READ_TOOLS = %w[search_catalog list_quotes].freeze
  QUOTE_PROPOSAL_TOOLS = %w[propose_create_quote propose_send_quote].freeze
  CATALOG_LIMIT = 8
  CATALOG_SCAN = 2000
  CATALOG_STOPWORDS = %w[de del la las los el un una unos unas para con por y].freeze
  MAX_ITEMS = 30

  # Palabra por palabra, sin acentos ni plurales («mantenimientos preventivos» encuentra
  # «Mantenimiento preventivo A/C»); primero los que traen más palabras.
  def tool_search_catalog(args)
    raise ArgumentError, 'No tienes acceso al Catálogo.' unless @grant.catalog_readable?

    items = catalog_matches(catalog_stems(args['query'])).first(CATALOG_LIMIT)
    { items: items.map { |i| { id: i.id, name: i.name, sku: i.sku, kind: i.kind, unit: i.unit, price: i.price.to_f } },
      currency: quote_settings.default_currency }
  end

  def tool_list_quotes(args)
    scope = @grant.quotes(@account.quotes).includes(:contact).order(created_at: :desc)
    scope = scope.where(contact_id: contacts.find(args['contact_id']).id) if args['contact_id'].present?
    scope = scope.where(contact_id: contacts.where(organization_id: args['organization_id']).select(:id)) if args['organization_id'].present?
    scope = scope.where(status: Quote::OPEN_STATUSES) if args['status'] == 'open'
    { quotes: scope.limit(Assistant::Tools::LIST_LIMIT).map { |quote| quote_ref(quote) } }
  end

  # Partidas del modelo (o de la tarjeta) → las que se guardan. Las del catálogo toman su
  # nombre, unidad y precio (si no se dio otro); las libres necesitan descripción y precio.
  def quote_items(raw)
    rows = Array(raw).first(MAX_ITEMS).map { |item| quote_item(item.to_h.stringify_keys) }
    raise ArgumentError, 'La cotización necesita al menos una partida.' if rows.empty?

    rows
  end

  # { net:, tax:, total: } igual que Quote#recalculate! (descuento por partida).
  def self.totals(items)
    net = items.sum { |item| item_net(item) }
    tax = items.sum { |item| (item_net(item) * item['tax_percent'].to_d / 100).round(2) }
    { 'net' => net.to_f, 'tax' => tax.to_f, 'total' => (net + tax).to_f }
  end

  def self.item_net(item)
    (item['quantity'].to_d * item['unit_price'].to_d * (1 - (item['discount_percent'].to_d / 100))).round(2)
  end

  # --- propuestas --------------------------------------------------------------------
  def prepare_create_quote(args)
    raise ArgumentError, 'No tienes permiso para crear cotizaciones (Ventas).' unless @grant.writable?(:sales)

    contact = contacts.find(args['contact_id'])
    items = quote_items(args['items'])
    currency = args['currency'].to_s.upcase.presence || quote_settings.default_currency
    opportunity = quote_opportunity(contact, args['opportunity_id'])
    payload = { 'contact_id' => contact.id, 'items' => items, 'currency' => currency, 'notes' => args['notes'].to_s,
                'opportunity_id' => opportunity&.id, 'create_opportunity' => opportunity.nil? && quote_settings.quotes_require_opportunity }
    [payload, quote_labels(contact, items, currency, opportunity, payload['create_opportunity'])]
  end

  def prepare_send_quote(args)
    quote = @grant.quotes(@account.quotes).find(args['quote_id'])
    raise ArgumentError, "La cotización #{quote.folio} ya no está abierta." unless quote.live?

    [{ 'quote_id' => quote.id }, { 'rows' => [['QUOTE', quote.folio], ['CLIENT', quote.contact&.name]] }]
  end

  private

  def quote_settings
    @quote_settings ||= CaseSetting.for_account(@account)
  end

  def quote_ref(quote)
    ref = { id: quote.id, folio: quote.folio, status: quote.status, contact: quote.contact&.name,
            created_at: local(quote.created_at), valid_until: quote.valid_until&.to_s }
    return ref unless @grant.quote_amounts_visible?(quote)

    ref.merge(net_total: quote.net_total.to_f, total: quote.total.to_f, currency: quote.currency)
  end

  def quote_item(item)
    catalog = @account.catalog_items.find_by(id: item['catalog_item_id']) if item['catalog_item_id'].present?
    description = item['description'].presence || catalog&.name
    raise ArgumentError, 'Cada partida necesita descripción o un producto del catálogo.' if description.blank?

    { 'catalog_item_id' => catalog&.id, 'description' => description.to_s.first(500), 'kind' => catalog&.kind,
      'unit' => item['unit'].presence || catalog&.unit, 'quantity' => item_quantity(item),
      'unit_price' => item_price(item, catalog, description), 'discount_percent' => item['discount_percent'].to_f.clamp(0, 100),
      'tax_percent' => quote_settings.default_tax_percent.to_f }
  end

  def catalog_matches(stems)
    scored = @account.catalog_items.where(active: true).limit(CATALOG_SCAN).filter_map do |item|
      text = GlobalSearch.normalize([item.name, item.sku, item.description].join(' '))
      hits = stems.count { |stem| text.include?(stem) }
      [item, hits] if hits.positive?
    end
    scored.sort_by { |(item, hits)| [-hits, item.name] }.map(&:first)
  end

  def catalog_stems(query)
    words = GlobalSearch.normalize(query).split.reject { |w| w.length < 2 || CATALOG_STOPWORDS.include?(w) }
    words.map { |w| w.length > 4 ? w.sub(/(es|s)\z/, '') : w }.uniq
  end

  def item_quantity(item) = [item['quantity'].to_f, 0.01].max

  def item_price(item, catalog, description)
    price = item['unit_price'].presence || catalog&.price
    raise ArgumentError, "Falta el precio de «#{description}»: pregúntaselo al usuario." if price.nil?

    price.to_f
  end

  # La oportunidad abierta que se pidió o, si no, la más reciente abierta del cliente.
  def quote_opportunity(contact, id)
    open = cases.commercial.where(contact_id: contact.id).where.not(status: %i[closed cancelled])
    return open.find(id) if id.present?

    open.order(updated_at: :desc).first
  end

  def quote_labels(contact, items, currency, opportunity, create_opportunity)
    totals = Assistant::QuoteTools.totals(items)
    opp = opportunity ? "#{opportunity.folio} · #{opportunity.title}" : (create_opportunity && I18n.t('assistant.quotes.new_opportunity'))
    { 'rows' => [['CLIENT', contact.name], ['OPPORTUNITY', opp]].select(&:last),
      'items' => items, 'currency' => currency, 'totals' => totals }
  end
end
