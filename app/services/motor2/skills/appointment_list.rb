# frozen_string_literal: true

# «Citas» — las citas del cliente en la plática (pueden ser varias: otro servicio, otro día o para otra persona: «una
# cita para mi esposa»). En la memoria, cada una con su reunión, sus servicios, para quién y cuándo; mover o cancelar
# pide cuál si hay más de una. En «Probar» no se crea la reunión: queda solo en la memoria (test).
#
#   memoria: state['appointments'] = [{ 'meeting_id', 'services' [], 'for', 'at', 'with', 'test', 'cancelled' }]
#            (las de antes: state['appointment'] = { 'meeting_id', 'services' }, se leen igual)
# Lo incluye Motor2::Skills::Appointments.
module Motor2::Skills::AppointmentList
  private

  # Eligió uno de los horarios que se le dieron (Motor2::SlotPick): que lo agende sin volver a ofrecer.
  def picked_note
    return nil unless @picked

    services = Array(state['offered_services']).presence
    "ELIGIÓ EL HORARIO: #{@picked['texto']}#{" con #{@picked['con']}" if @picked['con']} (inicio #{@picked['inicio']}). Llama " \
      "agendar_cita con ese inicio#{" y con=#{@picked['con']}" if @picked['con']}#{" y los servicios #{services.join(', ')}" if services} " \
      '(o mover_cita si está cambiando una ' \
      'cita); no le vuelvas a dar horarios.'
  end

  def entries
    list = Array(state['appointments'])
    legacy = state['appointment']
    list = [legacy] + list if legacy.is_a?(Hash) && legacy['meeting_id'] && list.none? { |e| e['meeting_id'] == legacy['meeting_id'] }
    list
  end

  # Las que siguen en pie (en «Probar», las que no se cancelaron).
  def active_entries
    entries.select { |e| e['test'] ? !e['cancelled'] : meeting_for(e)&.scheduled? }
  end

  def meeting_for(entry)
    @meetings ||= {}
    id = entry['meeting_id']
    id && (@meetings[id] ||= CaseMeeting.find_by(id: id))
  end

  def remember(entry)
    state['appointments'] = (entries + [entry.compact]).last(10)
    state.values.delete('appointment')
    state.values.delete('offered_slots')
  end

  def entry_text(entry)
    meeting = meeting_for(entry)
    at = meeting ? local(meeting.starts_at) : entry['at']
    who = meeting&.organizer&.name || entry['with']
    what = Array(entry['services']).join(' + ').presence
    [at, ("con #{who}" if who), what, ("para #{entry['for']}" if entry['for'].present?)].compact.join(' · ')
  end

  def booked_lines
    list = active_entries
    return nil if list.empty?

    lines = list.each_with_index.map { |e, i| "  #{i + 1}. #{entry_text(e)}" }.join("\n")
    "CITAS AGENDADAS (puede agendar otra —otro servicio, otro día o para otra persona— y moverlas o cancelarlas):\n#{lines}"
  end

  # En «Probar» no se crea la reunión: queda en la memoria para moverla, cancelarla o agendar otra.
  # En «Probar» la agenda no se entera de las citas de prueba: la misma hora con la misma persona se avisa aquí.
  def test_taken(slot)
    return nil unless test?

    busy = active_entries.find { |e| e['test'] && e['at'] == local(slot[:slot]) && e['with'] == slot[:agent_name] }
    return nil unless busy

    { error: "#{slot[:agent_name]} ya tiene esa hora (#{entry_text(busy)}).",
      nota: 'Ofrécele la misma hora con otra persona (ver_horarios con ese día y hora, sin «con») u otro horario.' }
  end

  def test_booking(slot)
    remember('test' => true, 'at' => local(slot[:slot]), 'with' => slot[:agent_name], 'services' => chosen_names,
             'for' => @for_whom)
    confirmation(slot[:slot], slot[:agent_name], minutes.minutes).merge(prueba: true)
  end

  # Lo que se le confirma: día, hora, con quién, dónde y (citas de servicio) servicios, total y duración.
  def confirmation(starts_at, with, length)
    add_booked_to_cart
    sourced({ ok: true, cita: local(starts_at), con: with, para: @for_whom, lugar: setting(:location).presence,
              servicios: chosen_names, desglose: services_breakdown, duracion_minutos: (length / 60).round,
              nota: 'Confírmale día, hora, con quién y dónde; si viene «desglose», dáselo tal cual (subtotal, IVA y total) y lo ' \
                    'que dura; pídele avisar con tiempo si no puede llegar.' }.compact)
  end

  # La que quiere mover o cancelar: si solo hay una, esa; si hay varias, la que dice «cita» (hora, día, servicio o
  # para quién) o se le pregunta cuál.
  def target(which)
    list = active_entries
    return [nil, { error: 'No tiene cita agendada.' }] if list.empty?
    return [list.first, nil] if list.size == 1 && !other_one?(list.first, which)
    return [nil, not_that_one(list)] if list.size == 1

    found = best_match(list, which)
    return [found, nil] if found

    [nil, { error: 'Tiene varias citas: pregúntale cuál (y pásala en «cita»).', citas: list.map { |e| entry_text(e) } }]
  end

  # «Cancela la de Laura» cuando la única cita es la de Mario (la de Laura no se agendó): no es esa.
  def other_one?(entry, which)
    text = Motor2::SlotPick.normalize(entry_text(entry))
    named = Motor2::SlotPick.normalize(which).split.select { |w| w.length > 3 && known_word?(w) }
    named.any? { |w| text.exclude?(w) }
  end

  # Un servicio del Catálogo o el nombre de alguien con cita en la plática.
  def known_word?(word)
    names = config.account.catalog_items.active.pluck(:name) + entries.filter_map { |e| e['for'] }
    names.any? { |n| Motor2::SlotPick.normalize(n).split.include?(word) }
  end

  def not_that_one(list)
    { error: 'Esa cita no está agendada.', citas: list.map { |e| entry_text(e) },
      nota: 'Dile que esa cita no quedó agendada y cuál sí tiene; pregúntale qué quiere hacer.' }
  end

  # La que más palabras comparte con lo que dijo («la de mi esposa», «la del viernes», «el facial»), si es una sola.
  def best_match(list, which)
    words = Motor2::SlotPick.normalize(which).split.select { |w| w.length > 2 } - %w[del las los una para cita]
    hits = list.group_by { |e| words.count { |w| Motor2::SlotPick.normalize(entry_text(e)).include?(w) } }
    top = hits.keys.max
    top.to_i.positive? && hits[top].size == 1 ? hits[top].first : nil
  end
end
