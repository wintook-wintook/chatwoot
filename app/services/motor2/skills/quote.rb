# frozen_string_literal: true

# Cotizar — los tres agentes listos (Functions::Extras#quote_mode; Atención a clientes solo en Comercial). Como Dali:
# con los productos y cantidades que pidió, arma la cotización con los precios del Catálogo (Quotes::Builder) y su
# oportunidad, para el vendedor de la empresa:
#   draft  (recomendado) queda en borrador; el vendedor recibe una nota con @mención para revisarla y mandarla;
#   send   se la manda al cliente por su conversación (Quotes::Delivery) y avisa al vendedor; a los N días, si sigue
#          sin respuesta, le pregunta si pudo revisarla (Motor2::QuoteFollowUpJob).
# Nunca descuentos ni precios fuera del Catálogo. En el chat de prueba no crea nada (enseña cómo quedaría).
#
#   memoria: state['quote'] = { 'id', 'folio' }
class Motor2::Skills::Quote < Motor2::Skills::Base
  ITEM = { type: 'object', properties: { producto: STR, cantidad: { type: 'number' } }, required: %w[producto] }.freeze
  MAX_ITEMS = 15

  def self.key = 'quote'

  def tools
    [fn('cotizar', 'Arma su cotización formal con productos del Catálogo, cuando ya sabes qué quiere y cuántos. Solo cuando la pide.',
        { partidas: { type: 'array', items: ITEM }, notas: STR }, %w[partidas])]
  end

  def instructions
    <<~TEXT.strip
      - COTIZAR: si pide una cotización formal y ya sabes qué productos y cuántos, llama cotizar (si falta, pregúntalo antes,
        en una pregunta). Nunca des descuentos ni precios que no regrese la herramienta.
    TEXT
  end

  def call(_name, args)
    items, missing = items_for(Array(args['partidas']).first(MAX_ITEMS))
    return { error: "No están en el Catálogo: #{missing.join(', ')}. Pregúntale qué producto es o pásalo al vendedor." } if missing.any?
    return { error: 'Falta qué productos quiere.' } if items.empty?
    return preview(items) if test? || @turn.conversation.nil?

    created(build(items, args['notas']))
  end

  private

  def created(quote)
    state['quote'] = { 'id' => quote.id, 'folio' => quote.folio }
    trace.event(:cotizacion, "#{quote.folio} (#{mode})")
    @turn.after_send { after(quote) }
    { ok: true, folio: quote.folio, total: quote.total.to_f, nota: note_for_agent }
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
    best = Array(Motor2::CatalogSearch.new(config.account).call(name)[:results]).first
    best && config.account.catalog_items.active.find_by(name: best[:nombre])
  end

  def preview(items)
    lines = items.map { |(item, qty)| { producto: item.name, cantidad: qty, precio: item.price.to_f } }
    @turn.seen << lines.to_json
    { ok: true, prueba: true, partidas: lines, total: lines.sum { |l| l[:precio] * l[:cantidad] }, nota: note_for_agent }
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
      quantity: qty, unit_price: item.price, discount_percent: 0, position: position,
      tax_percent: CaseSetting.for_account(config.account).default_tax_percent }
  end

  def note_for_agent
    return 'Ya quedó: dile que se la manda su asesor en un momento (no le des el total: lo revisa el asesor).' if mode == 'draft'

    'Ya se la mandamos por aquí con su liga: dile el folio y que cualquier duda te la resuelves.'
  end

  # Después de mandar el mensaje: la manda (si toca), avisa al vendedor y programa el seguimiento.
  def after(quote)
    tracking = @turn.tracking
    if mode == 'send'
      Quotes::Delivery.new(quote, Motor2::Delivery.sender(config.account)).deliver!
      Motor2::QuoteFollowUpJob.set(wait: function.quote_follow_days.days).perform_later(tracking.id, quote.id) if tracking
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
