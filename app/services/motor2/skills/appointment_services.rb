# frozen_string_literal: true

# «Citas» › citas de servicio (skills.appointments 'services' => true; «Atención a clientes» › Comercial ›
# «Si quiere una cita para un servicio»): el modelo dice qué servicios del Catálogo quiere y, si lo pidió, con quién.
# La cita dura la suma de duration_minutes de esos servicios (los que no la tienen cuentan los minutos de la cita) y se
# busca solo en la agenda de esa persona. Se guardan en la memoria (state['appointments'][]['services']) para moverla igual.
# Lo incluye Motor2::Skills::Appointments.
module Motor2::Skills::AppointmentServices
  MAX_SERVICES = 6
  MAX_SERVICE_MINUTES = 480

  private

  def services? = setting(:services) == true

  def before_slots(args) = missing_contact || choose(args)

  # Pidió cita y en este mensaje dijo el servicio sin duda («caballero» → Corte de caballero): a buscar horarios ya.
  def service_said(text)
    return nil unless services? && @turn.find_skill('areas')&.now.to_h['gestion'].in?([nil, 'cita'])

    Motor2::CatalogSearch.new(config.account).named_item(text)
  end

  def service_note
    "Dijo el servicio: «#{@service_said.name}». Si quiere cita, llama ver_horarios con ese servicio ahora (no le " \
      'preguntes antes si quiere algo más ni por estilos).'
  end

  def book_required = services? ? %w[inicio servicios] : %w[inicio]

  def minutes = @chosen.present? ? services_minutes : base_minutes

  def base_minutes = (setting(:minutes).presence || config.template.calendar_event_duration).to_i.clamp(15, 240)

  def service_params
    return {} unless services?

    { servicios: { type: 'array', items: Motor2::Tools::STR, description: 'Los servicios del Catálogo que quiere en esta cita' },
      con: { type: 'string', description: 'Con quién la quiere (su nombre), solo si lo pidió' } }
  end

  def services_instructions
    return '' unless services?

    "\n  Antes de ver horarios pregúntale qué servicio(s) quiere (del Catálogo) y pásalos en «servicios» a ver_horarios y " \
      "agendar_cita: la cita dura lo de esos servicios. Si pide con alguien, pásalo en «con» (atienden: #{people.to_sentence}). " \
      'Al darle horarios dile también cada servicio con su precio y lo que dura (como los regresa ver_horarios), y usa ' \
      'siempre el nombre del servicio tal como lo regresan las herramientas. Si tiene su cuenta y quiere agendar todo, ' \
      'llama ver_horarios sin servicios (usa los de su cuenta). ' \
      'No preguntes por tipos o estilos que no están en el Catálogo («¿clásico o moderno?»): si un servicio coincide con lo ' \
      'que dijo, es ese y busca horarios de una vez.'
  end

  # Citas de servicio: los servicios del Catálogo y con quién (cambian la duración y las agendas).
  def choose(args)
    return nil unless services?

    names = requested_services(args['servicios'])
    return { error: 'Primero pregúntale qué servicio quiere (de los del Catálogo) y pásalo en servicios.' } if names.empty?

    unclear = unclear_services(names)
    return unclear if unclear

    found = names.index_with { |name| catalog_service(name) }
    missing = found.select { |_, item| item.nil? }.keys
    return { error: "No están en el Catálogo: #{missing.join(', ')}. Pregúntale cuál de los servicios es." } if missing.any?

    @chosen = found.values.uniq
    with_person(args['con'])
  end

  # Los que pidió o, sin servicios, los de su cuenta («agéndame todo»: Motor2::Skills::QuoteCart).
  def requested_services(list)
    names = Array(list).map { |n| n.to_s.strip }.compact_blank.uniq
    @from_cart = names.empty?
    names = Array(state['cart']).pluck('name') if @from_cart
    names.first(MAX_SERVICES)
  end

  def unclear_services(names) = names.filter_map { |name| unclear_service(name) }.first || not_what_they_said(names)

  def catalog_service(name)
    Motor2::CatalogSearch.new(config.account).item(name)
  end

  # «Con Karla»: solo su agenda. Si no la encuentra, lo dice (no agenda con otra persona sin decirle).
  def with_person(name)
    return nil if name.blank? || customer_name?(name)

    words = name_words(name)
    match = calendars.select { |c| words.intersect?(name_words(c.user&.name)) }
    return { error: "No hay agenda de #{name}. Atienden: #{people.to_sentence}. Pregúntale con quién." } if match.empty?

    use_calendars(match.map(&:id))
  end

  # El modelo a veces pone en «con» el nombre del cliente o de para quién es: no es con quién la quiere.
  def customer_name?(name)
    words = name_words(name)
    [@turn.conversation&.contact&.name, @for_whom].compact.any? { |n| words.intersect?(name_words(n)) }
  end

  def name_words(name) = I18n.transliterate(name.to_s.downcase).split

  def calendars = UserCalendarIntegration.where(id: integration_ids).includes(:user).to_a

  def people = calendars.filter_map { |c| c.user&.name }.uniq

  # Desde aquí las agendas son esas (y el buscador de horarios se arma de nuevo).
  def use_calendars(ids)
    @integration_ids = ids
    @service = nil
  end

  def services_minutes = @chosen.sum { |item| item.duration_minutes || base_minutes }.clamp(15, MAX_SERVICE_MINUTES)

  def chosen_names = @chosen.presence&.map(&:name)

  # Cada servicio con su precio y lo que dura, y el total (para dárselos junto con los horarios y al confirmar).
  def services_detail
    @chosen.presence&.map { |i| { nombre: i.name, precio: i.price.to_f, minutos: i.duration_minutes || base_minutes } }
  end

  def services_total = @chosen.presence && @chosen.sum { |i| i.price.to_f }

  # «Corte de caballero + Facial hidratante · Mario» (o «… · Laura, su esposa (cliente: Mario)»).
  def meeting_title(contact)
    what = @chosen.present? ? chosen_names.join(' + ') : "Cita (#{kind})"
    who = @for_whom ? "#{@for_whom} (cliente: #{contact&.name})" : contact&.name
    "#{what} · #{who}"
  end

  # Cita de servicio: se mueve con lo mismo que dura y con la misma persona.
  def keep_for_move(entry)
    return unless services?

    names = Array(entry['services'])
    @chosen = names.filter_map { |n| config.account.catalog_items.active.find_by(name: n) }.presence
    organizer_id = meeting_for(entry)&.organizer_id
    ids = organizer_id ? UserCalendarIntegration.where(id: integration_ids, user_id: organizer_id).pluck(:id) : []
    use_calendars(ids) if ids.any?
  end
end
