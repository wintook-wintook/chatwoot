# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — «¿TIENES OTRA?»: OTRA UNIDAD PARA UN SERVICIO (conv. 398, 07/10/2026)
# ================================================================================
# «Oye pero el segundo es la misma grúa, necesito dos grúas diferentes, ¿tienes otra?» se tomaba
# como corrección de datos del 1️⃣ (dejaba «KM10.5 → KM10.5»). Ahora:
#   · ¿cuál?   el que nombra («el 2», «2️⃣», «el segundo»); si no, el que comparte unidad y hora
#              con otro servicio; si solo hay uno abierto, ese
#   · se cancela su tarea, esa unidad queda en metadata['excluir_unidades'] (el Scheduler ya no
#     la ofrece), se borra la unidad asignada y se vuelven a buscar horarios para el mismo día y hora
# nil = el mensaje no pide otra unidad o no se sabe para cuál: el motor sigue.
# ================================================================================

class ContactTrackings::ServiceRequests::OtherUnit
  # Solo CAMBIAR la unidad: «necesito otra grúa para el martes» es un servicio nuevo (Registry).
  ASK_RE = /\b(?:mism[oa]\s+(?:gr[uú]a|unidad|equipo)|(?:gr[uú]as?|unidad(?:es)?|equipos?)\s+(?:diferentes?|distint[oa]s?)|
             (?:tienes|tienen|hay)\s+otr[oa]|cambi\w*\s+(?:la|el|de)\s+(?:gr[uú]a|unidad|equipo))\b/xi
  ORDINALS = { 'primer' => 1, 'primero' => 1, 'primera' => 1, 'segundo' => 2, 'segunda' => 2,
               'tercer' => 3, 'tercero' => 3, 'tercera' => 3, 'cuarto' => 4, 'cuarta' => 4 }.freeze
  EXCLUDED_KEY = 'excluir_unidades'

  def self.asked?(text)
    text.to_s.match?(ASK_RE)
  end

  def initialize(tracking:, message:, timezone:, referenced: nil)
    @tracking = tracking
    @message = message
    @timezone = timezone
    @referenced = referenced
  end

  def call
    caso = target
    return nil if caso.nil? || route.nil?

    release(caso)
    ContactTrackings::ServiceRequests::Turn.new(tracking: @tracking, message: @message, branch: route, timezone: @timezone)
                                           .replan([ContactTrackings::ServiceRequests::Registry::Entry.new(ticket: caso, created: false)])
  end

  private

  def abiertos
    @abiertos ||= ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).to_a
  end

  def target
    numero = @referenced || ordinal
    return abiertos[numero - 1] if numero

    sharing_unit || (abiertos.one? ? abiertos.first : nil)
  end

  def ordinal
    palabra = ORDINALS.keys.find { |clave| @message.content.to_s.downcase.match?(/\b#{clave}\b/) }
    palabra && ORDINALS[palabra]
  end

  # El último servicio cuya tarea está en la misma unidad y a la misma hora que la de otro.
  def sharing_unit
    abiertos.reverse.find do |caso|
      tarea = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
      tarea && !tarea.cancelled? &&
        ContactTrackings::ServiceRequests::Taken.new(caso, offers: false).busy?(tarea.google_calendar_id, tarea.starts_at, tarea.ends_at)
    end
  end

  def release(caso)
    tarea = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    unidades = Array(caso.metadata[EXCLUDED_KEY]) + [tarea&.google_calendar_id] + Array(caso.metadata['oferta']).pluck('gcal')
    ContactTrackings::ServiceMeeting.new(tarea).cancel! if tarea && !tarea.cancelled?
    clear(caso, unidades.compact.uniq)
  end

  # Sin tarea, sin oferta y sin unidad asignada; con las unidades que ya no se le ofrecen.
  def clear(caso, unidades)
    campo = caso.metadata[ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY].to_s
    caso.update!(metadata: caso.metadata.except('meeting_id', 'estado', 'oferta').merge(EXCLUDED_KEY => unidades),
                 custom_attributes: caso.custom_attributes.to_h.except(campo))
  end

  def route
    @route ||= ContactTrackings::RouteMap.parse(@tracking.complementary_prompt.to_s).routes
                                         .find { |r| ContactTrackings::ServiceRequests::Turn.route?(r.escalation) }
  end
end
