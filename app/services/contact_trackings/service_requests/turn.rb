# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — UN TURNO CON @solicitudes (pieza 5, 26/09/2026)
# ================================================================================
# El mensaje cae en una ruta con @solicitudes:
#   Extractor (servicios) → Registry (un caso por servicio, reiteraciones) → respuesta con todos,
#   numerados por conversación (1️⃣ 2️⃣ 3️⃣), y UNA pregunta con lo que falta de cada uno.
# F3 agrega los horarios de cada servicio. Plan: docs/solicitudes_multiservicio_plan.md §4
#
# nil = el mensaje no pide servicios (saludo, pregunta): el motor sigue como siempre.
# ================================================================================

class ContactTrackings::ServiceRequests::Turn
  DIRECTIVE_RE = /@solicitudes\b/i
  NUMBERS = %w[0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟].freeze
  DAYS = %w[dom lun mar mié jue vie sáb].freeze
  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

  def self.route?(escalation)
    escalation.to_s.match?(DIRECTIVE_RE)
  end

  # Número del servicio para el cliente: su lugar entre los abiertos de la conversación.
  def self.number(ticket, conversation)
    lugar = ContactTrackings::ServiceRequests::Registry.open_cases(conversation).pluck(:id).index(ticket.id)
    lugar ? NUMBERS.fetch(lugar + 1, "#{lugar + 1}.") : '•'
  end

  def initialize(tracking:, message:, branch:, timezone:, context: nil)
    @tracking = tracking
    @message = message
    @branch = branch
    @timezone = timezone
    @context = context
  end

  def call
    servicios = ContactTrackings::ServiceRequests::Extractor.new(
      account: @message.account, text: @message.content, tracking: @tracking, context: @context
    ).call
    return nil if servicios.blank?

    entries = ContactTrackings::ServiceRequests::Registry.new(
      tracking: @tracking, message: @message, escalation: @branch&.escalation, timezone: @timezone
    ).register!(servicios)
    reply(entries)
  end

  private

  def reply(entries)
    lineas = entries.map { |entry| line(entry) }
    faltan = entries.filter_map { |entry| missing(entry) }
    cierre = faltan.any? ? "Para programarlos me falta: #{faltan.join('; ')}." : 'Un asesor revisa la disponibilidad y te confirma.'
    "#{header(entries)}\n\n#{lineas.join("\n")}\n\n#{cierre}"
  end

  def header(entries)
    nuevos = entries.count(&:created)
    return "Recibí #{entries.size == 1 ? '1 servicio' : "#{entries.size} servicios"}:" if nuevos == entries.size

    "Actualicé #{entries.size - nuevos == 1 ? '1 servicio' : "#{entries.size - nuevos} servicios"} que ya tenía" \
      "#{nuevos.positive? ? " y agregué #{nuevos}" : ''}:"
  end

  def line(entry)
    datos = entry.ticket.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY]
    partes = [datos['label'].presence || 'Servicio', route(datos), when_text(datos)].compact_blank
    "#{self.class.number(entry.ticket, @message.conversation)} #{partes.join(' · ')} (caso #{entry.ticket.folio.presence || entry.ticket.id})"
  end

  def route(datos)
    paradas = Array(datos['stops']).pluck('lugar')
    paradas.size > 1 ? "#{paradas.first} → #{paradas.last}" : paradas.first
  end

  def when_text(datos)
    return nil if datos['date'].blank?

    fecha = Date.iso8601(datos['date'])
    "#{DAYS[fecha.wday]} #{fecha.day} #{MONTHS[fecha.month - 1]}#{" #{datos['time']}" if datos['time']}"
  end

  # Sin fecha no se puede programar; sin ningún lugar tampoco. Una renta sin fecha de inicio igual.
  def missing(entry)
    datos = entry.ticket.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY]
    faltan = []
    faltan << 'la fecha' if datos['date'].blank?
    faltan << 'dónde es' if Array(datos['stops']).empty?
    return nil if faltan.empty?

    "del #{self.class.number(entry.ticket, @message.conversation)} #{faltan.join(' y ')}"
  end
end
