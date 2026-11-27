# frozen_string_literal: true

# Cotizar › «Ir armando la cuenta en el chat» (answers['quote']['cart'], Functions::Extras#quote_cart?): mientras el
# cliente pregunta precios, el agente le ofrece «¿Te lo agrego a tu cuenta?» y va armando la lista. Las cuentas las
# hace el código (el modelo no suma): cada cambio regresa la lista con su total listo para leer. Con «mándamela», la
# cotización formal sale de la cuenta (cotizar sin partidas) y, si ya tenía una, se actualiza la misma.
# Impuestos como en la cotización: si el producto dice «el precio ya incluye el impuesto», su precio es el final;
# si no, se suma el impuesto (subtotal + IVA = total). Con el objetivo «cita», la cuenta es lo que se agenda.
#
#   memoria: state['cart'] = [{ 'id' => catalog_item_id, 'name', 'qty' }], state['cart_declined'] (dijo que no)
# Lo incluye Motor2::Skills::Quote.
module Motor2::Skills::QuoteCart
  MAX_CART = 20
  CART_TOOLS = %w[agregar_a_cuenta quitar_de_cuenta ver_cuenta].freeze
  OFFERED = /¿[^¿?]*\b(agrego|agregar|añado|añadir|sumo|sumar|pongo|incluyo)\b[^¿?]*\bcuenta\b[^¿?]*\?/i

  def cart? = function.respond_to?(:quote_cart?) && function.quote_cart?

  def cart = Array(state['cart'])

  private

  def cart_tools
    return [] unless cart?

    [fn('agregar_a_cuenta', 'Agrega a su cuenta los productos o servicios que quiere (con cuántos). Regresa la cuenta con su total.',
        { partidas: { type: 'array', items: Motor2::Skills::Quote::ITEM } }, %w[partidas]),
     fn('quitar_de_cuenta', 'Quita de su cuenta un producto (o solo algunos, con cantidad). Regresa la cuenta con su total.',
        { producto: Motor2::Tools::STR, cantidad: { type: 'number' } }, %w[producto]),
     fn('ver_cuenta', 'Su cuenta como va: productos, cantidades y total.', {})]
  end

  def cart_instructions
    return '' unless cart?

    offer = if state['cart_declined']
              'Ya dijo que no quiere ir armando la cuenta: no se lo vuelvas a ofrecer.'
            else
              'Cuando le des el precio de algo del Catálogo que no está en su cuenta, ofrécele una vez «¿Te lo agrego a tu cuenta?».'
            end
    <<~TEXT.chomp

      - SU CUENTA: #{offer} Si dice que sí o pide agregar o quitar, usa agregar_a_cuenta / quitar_de_cuenta y enséñale la cuenta
        tal como la regresa la herramienta (texto, con su desglose). Si pregunta cuánto es en total, ver_cuenta (sus citas
        ya están en su cuenta). Nunca sumes tú. Para la cotización formal, llama cotizar sin partidas
        (usa su cuenta).
    TEXT
  end

  def cart_memory
    return '' unless cart? && cart.any?

    "SU CUENTA: #{cart.map { |c| "#{c['name']} ×#{c['qty']}" }.join(', ')} (ver_cuenta para el total)"
  end

  # Le ofreció agregarlo a la cuenta y contestó que no: ya no se le ofrece.
  def cart_prepare(history)
    return unless cart?

    list = Array(history)
    last = list.last.to_h
    return unless last[:role].to_s == 'user' && last[:content].to_s.match?(Motor2::Skills::Goal::DECLINE)

    asked = list[0...-1].reverse.find { |m| m[:role].to_s == 'assistant' }&.dig(:content).to_s
    state['cart_declined'] = true if asked.match?(OFFERED)
  end

  def cart_call(name, args)
    case name
    when 'agregar_a_cuenta' then add_to_cart(Array(args['partidas']).first(Motor2::Skills::Quote::MAX_ITEMS))
    when 'quitar_de_cuenta' then remove_from_cart(args['producto'], args['cantidad'])
    else cart_result
    end
  end

  def add_to_cart(rows)
    items, missing = items_for(rows)
    return { error: "No están en el Catálogo: #{missing.join(', ')}. Pregúntale cuál es." } if missing.any?
    return { error: 'Falta qué productos.' } if items.empty?

    list = cart.map(&:dup)
    items.each do |(item, qty)|
      row = list.find { |c| c['id'] == item.id }
      row ? row['qty'] += qty : list << { 'id' => item.id, 'name' => item.name, 'qty' => qty }
    end
    save_cart(list)
  end

  def remove_from_cart(name, qty)
    item = catalog_item(name.to_s)
    list = cart.map(&:dup)
    target = item && list.find { |c| c['id'] == item.id }
    return { error: 'Eso no está en su cuenta.', cuenta: cart_text(cart_items) } unless target

    less = qty.to_f
    less.positive? && less < target['qty'].to_f ? target['qty'] = target['qty'].to_f - less : list.delete(target)
    save_cart(list)
  end

  def save_cart(list)
    state['cart'] = list.first(MAX_CART).map { |c| c.merge('qty' => fmt_qty(c['qty'])) }
    trace.event(:cuenta, cart.map { |c| "#{c['name']} ×#{c['qty']}" }.join(' · '))
    cart_result
  end

  # [catalog_item, cantidad] de la cuenta (los que siguen activos).
  def cart_items
    items = config.account.catalog_items.active.where(id: cart.pluck('id')).index_by(&:id)
    cart.filter_map { |c| items[c['id']] && [items[c['id']], c['qty'].to_f] }
  end

  def cart_result
    items = cart_items
    return { cuenta: [], texto: 'Su cuenta está vacía.' } if items.empty?

    totals = Motor2::CartTotals.new(items, promo: ->(item) { promo(item) }).call
    text = cart_text(items, totals)
    @turn.seen << totals.to_json << text
    @turn.evidence << "Su cuenta: #{text}"
    totals.merge(texto: text, nota: 'Enséñale la cuenta tal cual (texto). Luego: ¿algo más, la cotización formal o, si aplica, agendar?')
  end

  def cart_text(items, totals = nil)
    totals ||= Motor2::CartTotals.new(items, promo: ->(item) { promo(item) }).call
    "Tu cuenta:\n#{Motor2::CartTotals.text(totals)}"
  end

  def fmt_qty(qty) = Motor2::CartTotals.qty(qty)
end
