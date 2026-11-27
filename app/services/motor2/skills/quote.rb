# frozen_string_literal: true

# Cotizar — los tres agentes listos (Functions::Extras#quote_mode; Atención a clientes solo en Comercial). Como Dali:
# con los productos y cantidades que pidió, arma la cotización con los precios del Catálogo (Quotes::Builder) y su
# oportunidad, para el vendedor de la empresa:
#   draft  (recomendado) queda en borrador; el vendedor recibe una nota con @mención para revisarla y mandarla;
#   send   se la manda al cliente por su conversación (Quotes::Delivery) y avisa al vendedor; a los N días, si sigue
#          sin respuesta, le pregunta si pudo revisarla (Motor2::QuoteFollowUpJob).
# Nunca descuentos ni precios fuera del Catálogo, salvo el precio de promoción de la campaña de Ofrecer mientras dure
# (CampaignSeller#promo_price_for). En el chat de prueba no crea nada (enseña cómo quedaría).
#
# Con «Ir armando la cuenta en el chat» (Motor2::Skills::QuoteCart) la cotización sale de su cuenta y, si ya tenía una,
# se actualiza la misma (no se crea otra).
#
#   memoria: state['quote'] = { 'id', 'folio' }
class Motor2::Skills::Quote < Motor2::Skills::Base
  include Motor2::Skills::QuoteCart

  ITEM = { type: 'object', properties: { producto: STR, cantidad: { type: 'number' } }, required: %w[producto] }.freeze
  MAX_ITEMS = 15

  def self.key = 'quote'

  def tools
    [fn('cotizar', 'Arma su cotización formal con productos del Catálogo, cuando ya sabes qué quiere y cuántos. Solo cuando la pide.' \
                   "#{' Sin partidas, con lo de su cuenta.' if cart?}",
        { partidas: { type: 'array', items: ITEM }, notas: STR }, cart? ? [] : %w[partidas]), *cart_tools]
  end

  def memory = cart_memory

  # Tocó la cuenta y no la enseñó con su desglose: se agrega tal cual la calculó el sistema.
  def polish(reply)
    return reply unless cart_shown_without_breakdown?(reply)

    question = reply[/¿[^¿?]*\?\s*\z/]
    [reply.sub(/¿[^¿?]*\?\s*\z/, '').strip, cart_text(cart_items), question].compact_blank.join("\n\n")
  end

  def prepare(history) = cart_prepare(history)

  def cart_shown_without_breakdown?(reply)
    cart? && reply.to_s.exclude?('Subtotal') && trace.tools.any? { |t| CART_TOOLS.include?(t['name']) && t['ok'] } && cart_items.any?
  end

  def instructions
    <<~TEXT.strip
      - COTIZAR: si pide una cotización formal y ya sabes qué productos y cuántos, llama cotizar (si falta, pregúntalo antes,
        en una pregunta). Nunca des descuentos ni precios que no regrese la herramienta.#{cart_instructions}
    TEXT
  end

  def call(name, args)
    return cart_call(name, args) unless name == 'cotizar'

    quote_call(args)
  end

  private

  def quote_call(args)
    data = missing_contact
    return { error: "Antes de cotizar pídele su #{data.join(' y ')} (en una pregunta) y guárdalo con actualizar_contacto." } if data.any?

    items, missing = quote_items(Array(args['partidas']).first(MAX_ITEMS))
    return { error: "No están en el Catálogo: #{missing.join(', ')}. Pregúntale qué producto es o pásalo al vendedor." } if missing.any?
    return { error: 'Falta qué productos quiere.' } if items.empty?
    return preview(items) if test? || @turn.conversation.nil?

    created(existing_quote ? rebuild(existing_quote, items) : build(items, args['notas']))
  end

  # Las partidas que dijo o, sin partidas, las de su cuenta.
  def quote_items(rows) = rows.empty? && cart? ? [cart_items, []] : items_for(rows)

  # La que ya se le armó en esta plática y sigue abierta: con la cuenta, se actualiza esa (no se crea otra).
  def existing_quote
    return nil unless cart?

    quote = config.account.quotes.find_by(id: state.dig('quote', 'id'))
    quote if quote&.draft? || quote&.sent?
  end

  def rebuild(quote, items)
    Quote.transaction do
      quote.items.destroy_all
      items.each_with_index { |(item, qty), i| quote.items.create!(item_attrs(item, qty, i)) }
      quote.recalculate!
      trace.event(:cotizacion, "#{quote.folio} actualizada")
      quote
    end
  end

  def created(quote)
    state['quote'] = { 'id' => quote.id, 'folio' => quote.folio }
    trace.event(:cotizacion, "#{quote.folio} (#{mode})")
    @turn.after_send { after(quote) }
    # En el vendedor de campaña, cotizar ya es interés: las imágenes «cuando muestre interés» van con este mensaje (una vez).
    Motor2::Skills::Files.attach_unsent(@turn, config, state, 'interest') if function.key == 'campaign_seller'
    qualify!(quote.folio)
    sourced_total(quote)
    { ok: true, folio: quote.folio, total: quote.total.to_f, nota: note_for_agent }
  end

  # El total es un monto que salió de la herramienta: se puede decir (Motor2::Runner#unsourced?, AreaChecks).
  def sourced_total(quote)
    @turn.seen << "total #{quote.total.to_f} #{quote.items.map { |i| i.try(:total).to_f }.join(' ')}"
    @turn.evidence << "Cotización #{quote.folio}: total #{quote.total.to_f}; #{delivery_text}"
  end

  def prospects? = function.key == 'prospects'

  def delivery_text = mode == 'send' ? 'se le manda por este chat con su liga' : 'queda en borrador para el vendedor'

  # Atención a prospectos: pedir la cotización lo califica, caliente.
  def qualify!(folio)
    return unless prospects?

    Motor2::Skills::Qualify.note_temperature(state, 'caliente')
    @turn.decide('qualified', "Pidió la cotización #{folio}")
  end

  # Los datos obligatorios que marcó la empresa (Atención a prospectos), antes de cotizar.
  def missing_contact
    return [] unless function.respond_to?(:missing_contact)

    function.missing_contact(@turn.conversation&.contact, @turn.noted_contact)
  end

  def function = config.function

  def mode = function.quote_mode

  # [{ catalog_item, quantity }] y los que no encontró en el Catálogo.
  def items_for(rows)
    found = rows.map do |row|
      name = row['producto'].to_s
      [name, catalog_item(name), [row['cantidad'].to_f, 1].max]
    end
    [found.select { |(_, item, _)| item }.map { |(_, item, qty)| [item, qty] }, found.reject { |(_, item, _)| item }.map(&:first)]
  end

  def catalog_item(name)
    Motor2::CatalogSearch.new(config.account).item(name)
  end

  def preview(items)
    lines = items.map do |(item, qty)|
      price = (promo(item) || item.price).to_f
      { producto: item.name, cantidad: qty, precio: price, importe: price * qty }
    end
    total = lines.sum { |l| l[:precio] * l[:cantidad] }
    # El total también es un monto que salió de la herramienta (Motor2::Runner#unsourced?).
    @turn.seen << lines.to_json << "total #{total}"
    @turn.evidence << "Cotización armada: #{lines.to_json}, total #{total}; #{delivery_text}"
    qualify!('PRUEBA-COT')
    { ok: true, prueba: true, partidas: lines, total: total, nota: note_for_agent }
  end

  def build(items, notes)
    Quote.transaction do
      quote = Quotes::Builder.new(config.account, seller || Motor2::Delivery.sender(config.account))
                             .create!({ contact_id: @turn.conversation.contact_id, notes: notes.to_s.first(1000).presence,
                                        assignee_id: seller&.id }, create_opportunity: true)
      items.each_with_index { |(item, qty), i| quote.items.create!(item_attrs(item, qty, i)) }
      quote.recalculate!
      quote
    end
  end

  def item_attrs(item, qty, position)
    { account_id: config.account.id, catalog_item_id: item.id, description: item.name, kind: item.kind, unit: item.unit,
      quantity: qty, unit_price: item.quote_unit_price(promo(item) || item.price), discount_percent: 0, position: position,
      tax_percent: item.quote_tax_percent, tax_rate_id: item.effective_tax_rate&.id, # Productos y servicios › Parámetros
      withholdings: item.quote_withholdings }
  end

  # El precio de promoción de la campaña (Ofrecer), si el producto lo tiene y sigue vigente.
  def promo(item)
    function.respond_to?(:promo_price_for) ? function.promo_price_for(item) : nil
  end

  def note_for_agent
    done = prospects? ? ' Con esto queda listo: despídete (ya no hagas las preguntas que faltaban).' : ''
    return "Ya quedó: dile que se la manda su asesor en un momento (no le des el total: lo revisa el asesor).#{done}" if mode == 'draft'

    "Ya se la mandamos por este chat con su liga (no por correo): dile el folio y que cualquier duda te la resuelves.#{done}"
  end

  # Después de mandar el mensaje: la manda (si toca) y avisa al vendedor. El seguimiento lo programa
  # Motor2::QuoteFollowUpJob.schedule al quedar enviada (aquí o, en borrador, cuando la manda el vendedor).
  def after(quote)
    tracking = @turn.tracking
    if mode == 'send'
      Quotes::Delivery.new(quote, Motor2::Delivery.sender(config.account),
                           ai_agent: ContactTrackings::AgentIdentity.for(config.template)).deliver!
    end
    notify(tracking, quote)
  end

  def notify(tracking, quote)
    return unless tracking

    who = seller ? "#{TrackingCampaigns::HandOff.mention(seller)} " : ''
    text = if mode == 'draft'
             "🧾 #{who}cotización #{quote.folio} en borrador: revísala y mándala."
           else
             "🧾 #{who}se le mandó la cotización #{quote.folio}."
           end
    Motor2::Delivery.note(tracking, @turn.conversation, text)
  end

  def seller
    return @seller if defined?(@seller)

    target = function.respond_to?(:areas) ? function.handoff_target('sales') : function.handoff_target
    @seller = config.account.users.find_by(id: target[:user_id])
  end
end
