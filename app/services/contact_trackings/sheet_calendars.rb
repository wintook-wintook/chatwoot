# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — LA AGENDA EN EL CALENDARIO DE LO QUE SE NOMBRÓ (F3)
# ================================================================================
# Una ruta con {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} dice: «los
# horarios salen del calendario de los remolques de los que se está hablando». Esto
# convierte lo que regresa la hoja en lo que AvailabilitySlotService ya entiende:
#
#   hoja → [link embed de TP-95]  →  id 7eef…@group.calendar.google.com
#   agente: booking_calendar_ids = { "178" => [24 calendarios] }
#   resultado:                     { "178" => ["7eef…@group.calendar.google.com"] }
#
# Solo cuentan los calendarios que el agente ya tiene configurados (una agenda de
# «Calendarios» y marcado para agendar): la hoja elige entre ellos, no agrega otros.
#
# nil = el agente no usa {{hoja_buscar:}} → la agenda sigue exactamente como antes.
# ================================================================================

class ContactTrackings::SheetCalendars
  # status: :ok · :needs_value (nadie nombró un valor: hay que preguntar) ·
  #         :unavailable (la hoja no respondió o sus calendarios no están configurados)
  # named_in: el mensaje donde se nombró lo buscado (con «?»); nil si los valores eran fijos.
  Outcome = Struct.new(:status, :integration_ids, :booking_calendars, :asked, :named_in, keyword_init: true)

  # Si algo falla, no se agenda en ningún calendario: nunca en todos.
  def self.unavailable_outcome
    Outcome.new(status: :unavailable, integration_ids: [], booking_calendars: {})
  end

  def self.for(tracking, message, branch)
    new(tracking, message, branch).call
  end

  def initialize(tracking, message, branch)
    @tracking = tracking
    @message = message
    @branch = branch
  end

  def call
    spec = lookup_spec
    return nil if spec.nil?

    result = ContactTrackings::SheetLookup.new(@tracking.account, spec, conversation: @message.conversation).call
    return asking(result.asked) if result.status == :needs_value
    return unavailable("la hoja respondió #{result.status} #{result.missing}") unless result.ok?

    narrow(result.found.map { |value| ContactTrackings::SheetLookup.calendar_id(value) })
      .tap { |outcome| outcome.named_in = result.source_message_id }
  end

  private

  # La de la ruta que se eligió; si esa ruta no trae una, la de las otras rutas (los
  # calendarios son de los remolques, no de una ruta: «sí, agéndalo» puede caer en otra).
  # Solo las que van DESPUÉS de la flecha: como fuente, una {{hoja_buscar:}} regresa datos
  # para responder (operador, placas…), no calendarios.
  def lookup_spec
    ContactTrackings::SheetLookup.parse_all(@branch&.escalation).first ||
      ContactTrackings::SheetLookup.agenda_specs(@tracking.complementary_prompt).first
  end

  def narrow(calendar_ids)
    booking = booking_for(calendar_ids)
    log_unconfigured(calendar_ids - booking.values.flatten)
    return unavailable('ninguno de sus calendarios está configurado en el agente') if booking.empty?

    Outcome.new(status: :ok, integration_ids: booking.keys.map(&:to_i), booking_calendars: booking)
  end

  # { agenda => [calendarios de lo nombrado] }, solo agendas de «Calendarios» del agente.
  def booking_for(calendar_ids)
    agendas = configured_agendas
    template&.booking_calendar_ids.to_h.each_with_object({}) do |(agenda, calendars), acc|
      next unless agendas.include?(agenda.to_i)

      mine = Array(calendars).map(&:to_s) & calendar_ids
      acc[agenda.to_s] = mine if mine.any?
    end
  end

  def configured_agendas
    Array(template&.calendar_integration_ids.presence || @tracking.calendar_integration_ids).map(&:to_i)
  end

  def template
    @tracking.tracking_template
  end

  def asking(column)
    Outcome.new(status: :needs_value, asked: column, integration_ids: [], booking_calendars: {})
  end

  def unavailable(reason)
    Rails.logger.warn "[TrackingBot] ⚠️ {{hoja_buscar:}} sin calendarios para agendar: #{reason}"
    self.class.unavailable_outcome
  end

  def log_unconfigured(ids)
    return if ids.empty?

    Rails.logger.warn "[TrackingBot] ⚠️ {{hoja_buscar:}} calendarios que no están en el agente: #{ids.join(', ')}"
  end
end
