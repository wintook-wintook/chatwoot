# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — EL CLIENTE ELIGE HORARIOS (pieza 5, F3, 26/09/2026)
# ================================================================================
# Con opciones ofrecidas (metadata['oferta'] de cada caso-servicio):
#   «1A y 3B»            → esas
#   «sí» / «apártalos»   → la primera opción de cada servicio con oferta
# Cada una se aparta como Tarea agendada en el calendario de SU equipo (ServiceMeeting);
# con @agendar_calendar(modo=tentativo) queda «[TENTATIVO]», si no, en firme.
# nil = no hay ofertas abiertas o el mensaje no elige nada: el motor sigue.
# ================================================================================

class ContactTrackings::ServiceRequests::Choice
  CODE_RE = /\b(\d{1,2})\s*([abc])\b/i
  YES_RE = /\A\W*(s[ií]|ok|va|claro|dale|de acuerdo|ap[aá]rta\w*|todos?|perfecto)\b/i

  def initialize(tracking:, message:, timezone:, tentative:)
    @tracking = tracking
    @message = message
    @timezone = timezone
    @tentative = tentative
  end

  def call
    abiertos = ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).to_a
    con_oferta = abiertos.select { |caso| caso.metadata['oferta'].present? }
    return nil if con_oferta.empty?

    elegidos = chosen(abiertos, con_oferta)
    return nil if elegidos.empty?

    apartados = elegidos.map { |caso, oferta| hold(caso, oferta) }
    reply(apartados, con_oferta.reject { |caso| elegidos.any? { |e| e.first.id == caso.id } })
  end

  private

  def chosen(abiertos, con_oferta)
    texto = @message.content.to_s
    codigos = texto.scan(CODE_RE)
    if codigos.any?
      codigos.filter_map { |num, letra| pick(abiertos[num.to_i - 1], "#{num}#{letra}") }.uniq { |caso, _| caso.id }
    elsif texto.match?(YES_RE)
      con_oferta.map { |caso| [caso, caso.metadata['oferta'].first] }
    else
      []
    end
  end

  def pick(caso, codigo)
    oferta = caso&.metadata&.dig('oferta')&.find { |o| o['code'].casecmp?(codigo) }
    oferta && [caso, oferta]
  end

  def hold(caso, oferta)
    cancel_previous(caso) # al mover (F4): la tarea anterior se cancela al apartar la nueva
    slot = { slot: Time.zone.parse(oferta['slot']), end_time: Time.zone.parse(oferta['end_time']),
             calendar_integration_id: oferta['cal_id'], google_calendar_id: oferta['gcal'] }
    tarea = ContactTrackings::ServiceMeeting.hold!(ticket: caso, slot: slot, title: caso.title, timezone: @timezone)
    ContactTrackings::ServiceMeeting.new(tarea).confirm! unless @tentative
    caso.update!(metadata: caso.metadata.except('oferta').merge('meeting_id' => tarea.id,
                                                                'estado' => @tentative ? 'apartado' : 'confirmado'))
    [caso, tarea.reload, oferta]
  end

  def cancel_previous(caso)
    anterior = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    ContactTrackings::ServiceMeeting.new(anterior).cancel! if anterior && !anterior.cancelled?
  end

  def reply(apartados, pendientes)
    titulo = @tentative ? '📌 Aparté:' : '✅ Agendé:'
    lineas = apartados.map { |caso, tarea, oferta| line(caso, tarea, oferta) }
    partes = ["#{titulo}\n#{lineas.join("\n")}"]
    partes << 'Quedan pendientes de confirmar: cuando me confirmes el servicio, los dejo en firme.' if @tentative
    partes << "Falta elegir horario de: #{pendientes.map { |c| number(c) }.join(', ')}." if pendientes.any?
    partes.join("\n\n")
  end

  def line(caso, tarea, oferta)
    inicio = tarea.starts_at.in_time_zone(@timezone)
    fin = tarea.ends_at.in_time_zone(@timezone)
    aviso = tarea.sync_failed? ? ' — un asesor confirma el horario' : ''
    "#{number(caso)} #{caso.metadata.dig('servicio', 'label') || caso.title} · #{day(inicio)} " \
      "#{inicio.strftime('%H:%M')}–#{fin.strftime('%H:%M')} (#{oferta['calendar_name']})#{aviso}"
  end

  def day(time)
    "#{ContactTrackings::ServiceRequests::Turn::DAYS[time.wday]} #{time.day} " \
      "#{ContactTrackings::ServiceRequests::Turn::MONTHS[time.month - 1]}"
  end

  def number(caso)
    ContactTrackings::ServiceRequests::Turn.number(caso, @message.conversation)
  end
end
