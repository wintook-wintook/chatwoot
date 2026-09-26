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
  KINDS = ['cama baja', 'low boy', 'pick up', 'pickup', 'unidad ligera', 'grua', 'hiab', 'plana', 'torton', 'rabon',
           'tracto', 'quinta', 'camion', 'plataforma', 'contenedor', 'flete'].freeze
  PRIORITIES = { 'baja' => 'low', 'media' => 'medium', 'normal' => 'medium', 'alta' => 'high',
                 'urgente' => 'urgent', 'low' => 'low', 'medium' => 'medium', 'high' => 'high', 'urgent' => 'urgent' }.freeze

  Entry = Struct.new(:ticket, :created, keyword_init: true)

  # Los casos-servicio abiertos de una conversación, en el orden en que se pidieron.
  def self.open_cases(conversation)
    CaseTicket.where(conversation_id: conversation.id).where.not(status: CaseTicket::CLOSED_STATUSES)
              .where('metadata ? :k', k: META_KEY).order(:created_at, :id)
  end

  def initialize(tracking:, message:, escalation:, timezone:)
    @tracking = tracking
    @message = message
    @conversation = message.conversation
    @escalation = escalation.to_s
    @timezone = timezone
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

  def serialize(servicio)
    fecha = ContactTrackings::ServiceRequests::DateResolver.new(timezone: @timezone).call(servicio.date_text, servicio.time_text)
    servicio.to_h.transform_keys(&:to_s).merge(
      'date' => fecha.date&.iso8601, 'time' => fecha.time, 'ambiguous' => fecha.ambiguous,
      'source_message_id' => @message.id
    )
  end

  def same?(anterior, nuevo)
    anterior.present? && key(anterior) == key(nuevo) && key(nuevo).compact.size >= 2
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
    ticket.update!(metadata: ticket.metadata.to_h.merge(META_KEY => datos))
    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    Entry.new(ticket: ticket, created: true)
  end

  # El último dato gana, pero un dato que ahora no vino no borra el que ya estaba.
  def update(ticket, datos)
    anterior = ticket.metadata[META_KEY].to_h
    combinado = anterior.merge(datos.reject { |_, valor| valor.blank? })
    ticket.update!(metadata: ticket.metadata.merge(META_KEY => combinado), description: description(combinado))
    Entry.new(ticket: ticket, created: false)
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
