# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — UN CASO POR SERVICIO (pieza 5, F2, 26/09/2026)
# ================================================================================
# Cada servicio que sacó el Extractor se vuelve un caso (CaseTicket) de la conversación, con
# sus datos en metadata['servicio']. El tipo y la prioridad salen del @crear_ticket(...) de la
# ruta. Plan: docs/solicitudes_multiservicio_plan.md §3.1
#
# REITERACIONES («solicito nuevamente el servicio…», ej. 6): antes de crear, cada servicio se
# compara con los casos ABIERTOS de la conversación que ya existían ANTES de este mensaje:
#   mismo tipo de equipo + misma fecha + mismo origen → es el mismo: se ACTUALIZA (último dato gana)
# Dentro de un mismo mensaje no se comparan entre sí: «02 camiones con hiab» son dos.
# ================================================================================

class ContactTrackings::ServiceRequests::Registry
  META_KEY = 'servicio'
  # Del más específico al más general: «camión con grúa tipo hiab» es un hiab (no una grúa ni
  # un camión) y «tracto con plana de 12 mts» es una plana (medido el 26/09 en la conv. 256).
  KINDS = ['cama baja', 'low boy', 'pick up', 'pickup', 'unidad ligera', 'hiab', 'plana', 'grua', 'torton', 'rabon',
           'quinta', 'tracto', 'camion', 'plataforma', 'contenedor', 'flete'].freeze
  PRIORITIES = { 'baja' => 'low', 'media' => 'medium', 'normal' => 'medium', 'alta' => 'high',
                 'urgente' => 'urgent', 'low' => 'low', 'medium' => 'medium', 'high' => 'high', 'urgent' => 'urgent' }.freeze

  Entry = Struct.new(:ticket, :created, keyword_init: true)

  # Los casos-servicio abiertos de una conversación, en el orden en que se pidieron.
  def self.open_cases(conversation)
    CaseTicket.where(conversation_id: conversation.id).where.not(status: CaseTicket::CLOSED_STATUSES)
              .where('metadata ? :k', k: META_KEY).order(:created_at, :id)
  end

  # text: el del mensaje con sus adjuntos (pieza 7); sin él, el contenido del mensaje.
  def initialize(tracking:, message:, escalation:, timezone:, text: nil)
    @tracking = tracking
    @message = message
    @conversation = message.conversation
    @escalation = escalation.to_s
    @timezone = timezone
    @text = text.presence || message.content.to_s
  end

  # El cliente contestó lo que se le pidió («es escombro, 14 t») sin pedir otro servicio:
  # se completa ESE caso (campos, y fecha u hora si las dijo), no se abre otro.
  def complete!(ticket)
    datos = with_new_date(ticket.metadata[META_KEY].to_h)
    ticket.update!(metadata: ticket.metadata.merge(META_KEY => datos))
    store_fields(ticket, datos)
    Entry.new(ticket: ticket, created: false)
  end

  def register!(services)
    previos = self.class.open_cases(@conversation).to_a
    services.map do |servicio|
      datos = serialize(servicio)
      igual = previos.find { |caso| same?(caso.metadata[META_KEY], datos) }
      next create(datos) if igual.nil?

      previos.delete(igual)
      update(igual, datos)
    end
  end

  private

  # La fecha o la hora que faltaban, si este mensaje las trae. Lo que ya tenía no se toca.
  def with_new_date(datos)
    nueva = ContactTrackings::ServiceRequests::DateResolver.new(timezone: @timezone).call(@text, @text)
    if datos['date'].blank? && nueva.date
      datos = datos.merge('date' => nueva.date.iso8601, 'date_text' => @text.truncate(80), 'ambiguous' => nueva.ambiguous)
    end
    datos = datos.merge('time' => nueva.time, 'time_text' => nueva.time) if datos['time'].blank? && nueva.time
    datos
  end

  def serialize(servicio)
    fecha = ContactTrackings::ServiceRequests::DateResolver.new(timezone: @timezone).call(servicio.date_text, servicio.time_text)
    servicio.to_h.transform_keys(&:to_s).merge(
      'date' => fecha.date&.iso8601, 'time' => fecha.time, 'ambiguous' => fecha.ambiguous,
      'source_message_id' => @message.id
    )
  end

  # Mismo equipo, y fecha y origen iguales — o que el caso anterior todavía no tenía
  # (observación SSUSA 9: «para el 3 de octubre» después de «necesito un hiab» abría otro caso).
  def same?(anterior, nuevo)
    return false if anterior.blank?

    antes = key(anterior)
    ahora = key(nuevo)
    return false unless antes.first == ahora.first && ahora.compact.size >= 2

    antes.drop(1).zip(ahora.drop(1)).all? { |viejo, nuevo_dato| viejo.nil? || viejo == nuevo_dato }
  end

  def key(datos)
    texto = fold("#{datos['equipment_type']} #{datos['label']}")
    [KINDS.find { |k| texto.include?(k) } || texto.split.first, datos['date'], fold(Array(datos['stops']).first&.dig('lugar')).presence]
  end

  def create(datos)
    ticket = Cases::OrchestratorService.new(account: @message.account, contact: @conversation.contact, conversation: @conversation)
                                       .create_from_ai(message: @message, tracking: @tracking, title: title(datos),
                                                       description: description(datos), priority: priority,
                                                       case_type_id: case_type_id, force_priority: priority.present?)
    ticket.update!(metadata: ticket.metadata.to_h.merge(META_KEY => datos).merge(assigned_meta))
    store_fields(ticket, datos)
    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    Entry.new(ticket: ticket, created: true)
  end

  # El último dato gana, pero un dato que ahora no vino no borra el que ya estaba.
  def update(ticket, datos)
    anterior = ticket.metadata[META_KEY].to_h
    combinado = anterior.merge(datos.reject { |_, valor| valor.blank? })
    ticket.update!(metadata: ticket.metadata.merge(META_KEY => combinado), description: description(combinado))
    store_fields(ticket, combinado)
    Entry.new(ticket: ticket, created: false)
  end

  # Los campos particulares del tipo de caso (observación SSUSA 2), con lo que ya tenía.
  def store_fields(ticket, datos)
    campos = ContactTrackings::ServiceRequests::Fields.new(account: @message.account, case_type_id: ticket.case_type_id,
                                                           skip: ticket.metadata[ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY])
    return unless campos.any?

    resultado = campos.call(service_text: service_text(datos), message_text: @text,
                            previous: ticket.custom_attributes.to_h.slice(*field_keys(ticket)))
    ticket.update!(custom_attributes: ticket.custom_attributes.to_h.merge(resultado.found),
                   metadata: ticket.metadata.merge(ContactTrackings::ServiceRequests::Fields::PENDING_KEY => resultado.missing))
  end

  # @solicitudes(asignar=unidad): el campo del tipo de caso que recibe la unidad apartada
  # (Choice#hold). Lo llena el sistema, no el cliente.
  ASSIGN_RE = /@solicitudes\s*\(\s*asignar\s*=\s*([^)\s,]+)\s*\)/i

  def assigned_meta
    clave = @escalation[ASSIGN_RE, 1]
    clave.present? ? { ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY => clave } : {}
  end

  def field_keys(ticket)
    ticket.case_type&.case_type_fields&.map(&:key) || []
  end

  # La descripción del caso y la fecha ya resuelta (el campo «Fecha» la quiere como día exacto).
  def service_text(datos)
    [description(datos), datos['date'].present? ? "Fecha del servicio (exacta): #{datos['date']}" : nil].compact.join("\n")
  end

  def title(datos)
    paradas = Array(datos['stops']).pluck('lugar')
    ruta = paradas.size > 1 ? " — #{paradas.first} → #{paradas.last}" : ''
    "#{datos['label'].presence || datos['equipment_type'].presence || 'Servicio'}#{ruta}".truncate(250)
  end

  def description(datos)
    what_lines(datos).merge(load_lines(datos)).filter_map { |etiqueta, valor| "#{etiqueta}: #{valor}" if valor.present? }.join("\n")
  end

  def what_lines(datos)
    { 'Equipo' => [datos['equipment_type'], (datos['capacity_t'] && "#{datos['capacity_t'].to_s.delete_suffix('.0')} t")].compact.join(' '),
      'Ruta' => Array(datos['stops']).map { |p| "#{p['tipo']}: #{p['lugar']}" }.join(' → '),
      'Fecha' => [datos['date_text'], datos['time_text']].compact.join(' '), 'Duración' => datos['duration_text'] }
  end

  def load_lines(datos)
    { 'Carga' => datos['cargo'], 'Peso' => datos['weight_t'] && "#{datos['weight_t']} t", 'Medidas' => datos['dimensions'],
      'Folios' => Array(datos['folios']).join(', '), 'Responsable en sitio' => datos['site_contact'],
      'Modalidad' => datos['mode'], 'Notas' => datos['notes'] }
  end

  # @crear_ticket(tipo=…, prioridad=…) de la ruta.
  def overrides
    @overrides ||= @escalation[Cases::TicketCreatorService::DIRECTIVE_RE, 1].to_s.split(',').to_h do |par|
      clave, valor = par.split('=', 2).map { |parte| parte.to_s.strip }
      [clave.to_s.downcase, valor]
    end
  end

  def priority
    PRIORITIES[overrides['prioridad'].to_s.downcase]
  end

  def case_type_id
    nombre = overrides['tipo']
    nombre.present? ? @message.account.case_types.where('LOWER(name) = ?', nombre.downcase).pick(:id) : nil
  end

  def fold(text)
    I18n.transliterate(text.to_s).downcase.strip
  end
end
