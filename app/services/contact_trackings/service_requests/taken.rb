# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LO QUE YA TOMARON LOS OTROS SERVICIOS DE LA CONVERSACIÓN
# ================================================================================
# Conv. 398 (07/10/2026): dos hiab para el domingo 06:00 se ofrecieron en la MISMA unidad (TP-111)
# y con «sí» se apartaron los dos ahí. Cada servicio se planeaba solo; Google todavía no tenía el
# evento del otro porque ninguno estaba apartado al ofrecer.
#
# Aquí: las tareas activas y (si se pide) las ofertas abiertas de los OTROS casos-servicio de la
# conversación. Una unidad está ocupada si alguno de esos horarios se le encima.
# ================================================================================

class ContactTrackings::ServiceRequests::Taken
  Interval = Struct.new(:gcal, :from, :to, keyword_init: true)

  # offers: false → solo lo apartado (para Choice: elegir una opción ofrecida no la bloquea a sí misma).
  def initialize(ticket, offers: true)
    @ticket = ticket
    @offers = offers
  end

  def busy?(gcal, from, to)
    intervals.any? { |rango| rango.gcal == gcal && rango.from < to && from < rango.to }
  end

  # Las unidades ocupadas en algún momento de [from, to).
  def calendars_between(from, to)
    intervals.select { |rango| rango.from < to && from < rango.to }.map(&:gcal).uniq
  end

  private

  def intervals
    @intervals ||= others.flat_map { |caso| meeting_intervals(caso) + offer_intervals(caso) }
  end

  def others
    return [] if @ticket.conversation.nil?

    ContactTrackings::ServiceRequests::Registry.open_cases(@ticket.conversation).where.not(id: @ticket.id).to_a
  end

  def meeting_intervals(caso)
    tarea = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    return [] if tarea.nil? || tarea.cancelled? || tarea.google_calendar_id.blank?

    [Interval.new(gcal: tarea.google_calendar_id, from: tarea.starts_at, to: tarea.ends_at)]
  end

  def offer_intervals(caso)
    return [] unless @offers

    Array(caso.metadata['oferta']).map do |oferta|
      Interval.new(gcal: oferta['gcal'], from: Time.zone.parse(oferta['slot']), to: Time.zone.parse(oferta['end_time']))
    end
  end
end
