# frozen_string_literal: true

# «Citas» › citas de servicio con la cuenta y los precios: el desglose para confirmar la cita (subtotal sin IVA, IVA y
# total), lo agendado entra a «su cuenta» (Motor2::Skills::QuoteCart) para que «¿cuánto es en total?» sume todas sus
# citas, y un servicio que puede ser dos («corte» → dama o caballero; «facial» → hidratante o limpieza profunda) se
# pregunta en vez de adivinar. Lo incluye Motor2::Skills::Appointments.
module Motor2::Skills::ServiceCart
  private

  # Los servicios con su precio, subtotal sin IVA, IVA y total (Motor2::CartTotals), para confirmarle la cita.
  def services_breakdown
    return nil if @chosen.blank?

    Motor2::CartTotals.text(Motor2::CartTotals.new(@chosen.map { |i| [i, 1] }).call)
  end

  # Con «su cuenta» prendida, lo que agenda entra a su cuenta (así «¿cuánto es en total?» suma todas sus citas);
  # si agendó lo de su cuenta, ya está ahí.
  def add_booked_to_cart
    quote = @turn.find_skill('quote')
    return unless @chosen.present? && !@from_cart && quote&.cart?

    state['cart'] = @chosen.each_with_object(Array(state['cart']).map(&:dup)) { |item, list| add_one(list, item) }
  end

  def add_one(list, item)
    row = list.find { |c| c['id'] == item.id }
    row ? row['qty'] = row['qty'].to_f + 1 : list << { 'id' => item.id, 'name' => item.name, 'qty' => 1 }
  end

  # El modelo eligió «Corte de caballero» pero en su último mensaje el cliente dijo solo «otro corte» (para su esposa):
  # se le pregunta cuál, no se supone (Motor2::CatalogSearch#ambiguous_in).
  def not_what_they_said(names)
    open = Motor2::CatalogSearch.new(config.account).ambiguous_in(@turn.last_customer)
    head, items = open.find { |h, _| names.any? { |n| GlobalSearch.normalize(n).split.first == h } }
    return nil unless head

    { error: "No dijo cuál: puede ser #{items.map(&:name).join(' o ')}. Pregúntale cuál quiere (sin dar horarios todavía)." }
  end

  # «Corte de cabello» cuando hay «Corte de dama» y «Corte de caballero»: se pregunta cuál (no se adivina).
  def unclear_service(name)
    search = Motor2::CatalogSearch.new(config.account)
    return nil if search.named_item(name)

    word = GlobalSearch.normalize(name).split.find { |w| w.length > 3 }
    close = search.call(name)[:results].to_a.pluck(:nombre).select { |o| word && GlobalSearch.normalize(o).include?(word) }
    return nil if close.size < 2

    { error: "«#{name}» puede ser: #{close.join(' o ')}. Pregúntale cuál quiere (sin dar horarios todavía)." }
  end
end
