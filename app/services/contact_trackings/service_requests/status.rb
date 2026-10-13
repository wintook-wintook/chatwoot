# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — «¿SON DOS GRÚAS?»: EL RESUMEN DE SUS SERVICIOS (conv. 398/401, 07/10/2026)
# ================================================================================
# «no entendí, ¿son dos grúas?» caía en la agenda general («¿Qué tipo necesitas?»). Si el cliente
# pregunta por SUS servicios y hay casos abiertos, se contesta con cada uno: qué es, dónde, cuándo,
# en qué estado y en qué unidad, y lo que le falta. Sin IA.
# Una pregunta de catálogo («¿qué tipos de grúas manejan?») no entra: tiene que hablar de lo suyo.
# nil = no es una pregunta de estado o no hay servicios: el turno sigue.
# ================================================================================

class ContactTrackings::ServiceRequests::Status
  ABOUT_RE = /gr[uú]as?|servicios?|unidad(?:es)?|casos?|citas?|apart|agend|equipos?/i
  OWN_RE = /no\s+entend|\b(?:mis|tengo|llevo|qued[oó]|quedaron|me\s+(?:apartaste|agendaste|diste)|c[oó]mo\s+(?:va|van)|
            son\s+(?:dos|tres|cuatro|\d+)|cu[aá]nt[oa]s\s+(?:son|tengo|llevo|me))\b/xi
  STATES = { 'apartado' => '📌 apartado', 'esperando_pago' => '💳 esperando pago', 'confirmado' => '✅ confirmado' }.freeze

  def self.asked?(text)
    texto = text.to_s
    texto.match?(OWN_RE) && texto.match?(ABOUT_RE) && (texto.include?('?') || texto.match?(/no\s+entend/i))
  end

  def initialize(message:, timezone:)
    @message = message
    @timezone = timezone
  end

  def call
    return nil unless self.class.asked?(@message.content)

    casos = ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).to_a
    return nil if casos.empty?

    total = casos.one? ? '1 servicio' : "#{casos.size} servicios"
    ["Tienes #{total}:", casos.map { |caso| line(caso) }.join("\n"), closing(casos)].compact.join("\n\n")
  end

  private

  def line(caso)
    datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
    partes = [datos['label'].presence || caso.title, place(datos), when_text(datos), STATES[caso.metadata['estado']], unit(caso)]
    "#{number(caso)} #{partes.compact_blank.join(' · ')} (caso #{caso.folio.presence || caso.id})"
  end

  def closing(casos)
    partes = casos.filter_map { |caso| missing(caso) }
    partes << 'Los apartados quedan en firme cuando me confirmes el servicio.' if casos.any? { |c| c.metadata['estado'] == 'apartado' }
    partes << choose_text(casos)
    partes.compact.presence&.join("\n")
  end

  def choose_text(casos)
    con_oferta = casos.select { |caso| caso.metadata['oferta'].present? }
    "Falta elegir horario de: #{con_oferta.map { |caso| number(caso) }.join(', ')}." if con_oferta.any?
  end

  def missing(caso)
    datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
    faltan = ContactTrackings::ServiceRequests::Fields.missing_labels(caso)
    faltan << 'la fecha' if datos['date'].blank?
    faltan << 'la hora' if datos['date'].present? && datos['time'].blank? && caso.metadata['meeting_id'].blank?
    "Al #{number(caso)} le falta: #{faltan.join(', ')}." if faltan.any?
  end

  def unit(caso)
    campo = caso.metadata[ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY]
    campo.present? && caso.metadata['meeting_id'].present? ? caso.custom_attributes[campo].presence : nil
  end

  def place(datos)
    paradas = Array(datos['stops']).pluck('lugar')
    paradas.size > 1 ? "#{paradas.first} → #{paradas.last}" : paradas.first
  end

  def when_text(datos)
    return nil if datos['date'].blank?

    fecha = Date.iso8601(datos['date'])
    dias = ContactTrackings::ServiceRequests::Turn::DAYS
    meses = ContactTrackings::ServiceRequests::Turn::MONTHS
    "#{dias[fecha.wday]} #{fecha.day} #{meses[fecha.month - 1]}#{" #{datos['time']}" if datos['time']}"
  end

  def number(caso)
    ContactTrackings::ServiceRequests::Turn.number(caso, @message.conversation)
  end
end
