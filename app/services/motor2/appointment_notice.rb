# frozen_string_literal: true

# Motor 2.0 — los tres agentes listos: lo de la cita después de agendarla (Functions::Extras#appointment_notice):
#   - recordatorio: un día antes (o 2 h antes, si se agendó para el mismo día) con día, hora y con quién;
#   - si la marcan «no llegó» (CaseMeeting no_show), al rato le ofrece otro horario (lo mueve el agente con
#     sus herramientas de citas cuando contesta).
# Dentro de las 24 h de WhatsApp se escribe libre; si ya pasaron, con la plantilla que eligió la empresa
# (Motor2::LateMessage). Si se movió o canceló la cita, el aviso viejo no sale.
module Motor2::AppointmentNotice
  BEFORE = 24.hours
  SHORT_BEFORE = 2.hours
  NO_SHOW_AFTER = 3.hours

  module_function

  def schedule!(tracking, meeting)
    function = Motor2::Config.for(tracking).function
    return unless function.respond_to?(:appointment_notice) && function.appointment_notice[:on]

    at = meeting.starts_at - BEFORE
    at = meeting.starts_at - SHORT_BEFORE if at < 1.hour.from_now
    stamp = meeting.starts_at.iso8601
    Motor2::AppointmentNoticeJob.set(wait_until: at).perform_later(tracking.id, meeting.id, 'reminder', stamp) if at.future?
    Motor2::AppointmentNoticeJob.set(wait_until: meeting.ends_at + NO_SHOW_AFTER).perform_later(tracking.id, meeting.id, 'no_show', stamp)
  end

  # ¿Sigue tocando? (la misma cita, a la misma hora, y en el estado que corresponde).
  def due?(meeting, kind, stamp)
    return false unless meeting && meeting.starts_at.iso8601 == stamp

    kind == 'reminder' ? meeting.scheduled? || meeting.rescheduled? : meeting.no_show?
  end

  def text(tracking, meeting, kind)
    name = tracking.contact&.name.to_s.split.first
    hello = name.present? && !name.match?(/\A[+\d]/) ? "¡Hola #{name}!" : '¡Hola!'
    when_text = Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(zone(tracking)))
    with = meeting.organizer&.name.to_s.split.first
    if kind == 'reminder'
      "#{hello} Te recuerdo tu cita del #{when_text}#{" con #{with}" if with.present?}. ¿Nos confirmas que sí llegas?"
    else
      "#{hello} Te esperábamos en tu cita del #{when_text}. ¿Quieres que te agende otro horario?"
    end
  end

  def deliver(tracking, meeting, kind)
    config = Motor2::Config.for(tracking)
    message = Motor2::VoiceText.call(config, text(tracking, meeting, kind)) # con la voz de la empresa o del agente
    sent = Motor2::LateMessage.deliver(tracking, message, template: config.function.appointment_notice[:template])
    not_sent(tracking, meeting, kind) unless sent
  end

  # No se pudo (ventana cerrada y sin plantilla): que quien atiende la cita lo sepa y le escriba.
  def not_sent(tracking, meeting, kind)
    return unless tracking.conversation

    who = meeting.organizer ? "#{TrackingCampaigns::HandOff.mention(meeting.organizer)} " : ''
    what = kind.to_s == 'reminder' ? 'el recordatorio de la cita' : 'el mensaje de la cita a la que no llegó'
    Motor2::Delivery.note(tracking, tracking.conversation,
                          "⚠️ #{who}no se le pudo mandar #{what}: ya pasaron 24 h desde su último mensaje y el agente no tiene " \
                          'plantilla para el recordatorio de cita. Escríbele tú o elige una en la pestaña Seguimiento.')
  end

  def zone(tracking) = Motor2::Config.for(tracking).zone
end
