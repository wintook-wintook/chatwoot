# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — UN BLOQUE POR SERVICIO (observaciones SSUSA 22/10, F3)
# ================================================================================
# «No se entiende»: íconos, estados y datos en renglones que cada celular corta distinto.
# Cada servicio sale siempre igual, y los horarios en columnas:
#
#   *Servicio 1* · Carmen → Villahermosa
#   Cama baja · 40 t · 16.15 m
#   mié 21 oct · Caso UNI-00029
#   Estado: Por confirmar (la de las 12:00 es la que pediste)
#   ```
#   Op  Horario      Unidad
#   A   12:00-13:00  TP-46
#   ```
#   Falta: ubicación de destino
#
# La tabla va en bloque monoespaciado solo donde se alinea: WhatsApp (```) y Telegram (``` →
# <pre>, ver Channel::Telegram). En otros canales, una opción por renglón. Máximo 30
# caracteres y sin íconos dentro del bloque: miden distinto y rompen la alineación.
# ================================================================================

class ContactTrackings::ServiceRequests::Block
  WIDTH = 30
  STATES = { 'apartado' => 'Apartado', 'esperando_pago' => 'Esperando pago', 'confirmado' => 'Confirmado',
             'cancelado' => 'Cancelado' }.freeze
  DEFAULT_STATE = 'Por confirmar'

  def initialize(conversation:, timezone:)
    @conversation = conversation
    @timezone = timezone
    @channel = conversation.inbox&.channel_type
  end

  # plan: el del Scheduler (opciones, nota, unidades). held: la opción recién apartada ({'slot', 'end_time',
  # 'calendar_name'}); sin ella, la tarea del caso. missing: etiquetas de lo que falta.
  def service(caso, plan: nil, missing: [], held: nil, sync_failed: false)
    datos = caso.metadata[ContactTrackings::ServiceRequests::Registry::META_KEY].to_h
    held ||= meeting_slot(caso)
    ofertas = Array(plan&.offers)
    lineas = [title(caso, datos), related(plan), unit_lines(plan, datos, ofertas.presence || [held].compact, route(datos)),
              date_line(caso, datos), state_line(caso, plan), note_line(plan),
              schedule_line(plan, ofertas, held, sync_failed), missing_line(missing)]
    lineas.compact_blank.join("\n")
  end

  def number(caso)
    ContactTrackings::ServiceRequests::Registry.open_cases(@conversation).pluck(:id).index(caso.id).to_i + 1
  end

  private

  def bold(texto)
    case @channel
    when 'Channel::Whatsapp' then "*#{texto}*"
    when 'Channel::Telegram' then "**#{texto}**"
    else texto
    end
  end

  def monospace?
    %w[Channel::Whatsapp Channel::Telegram].include?(@channel)
  end

  # Con ruta, el título es la ruta y lo pedido va abajo; sin ruta, lo pedido va en el título.
  def title(caso, datos)
    "#{bold("Servicio #{number(caso)}")} · #{route(datos) || label(caso, datos)}"
  end

  def route(datos)
    paradas = Array(datos['stops']).pluck('lugar').compact_blank
    paradas.size > 1 ? "#{paradas.first} → #{paradas.last}" : paradas.first
  end

  # Observación SSUSA 1: no había lo pedido; lo que sigue es lo más parecido.
  def related(plan)
    return nil if plan&.related.blank? || plan.units.blank?

    "#{plan.related[0].upcase}#{plan.related[1..]}"
  end

  # La unidad con sus datos («Cama baja · 40 t · 16.15 m»); con varias, una por renglón con su nombre.
  # Sin datos de la hoja, lo que pidió el cliente (si no salió ya en el título).
  def unit_lines(plan, datos, ofertas, ruta)
    unidades = plan&.units.presence || offer_units(ofertas)
    return ruta && datos['label'].presence if unidades.empty?

    return unidades.values.first if unidades.one?

    named_units(unidades, ofertas)
  end

  # Lo que guardó el Scheduler en cada opción (para la pregunta de Choice y lo apartado).
  def offer_units(ofertas)
    ofertas.select { |oferta| oferta['unidad'].present? }.to_h { |oferta| [oferta['gcal'], oferta['unidad']] }
  end

  def named_units(unidades, ofertas)
    nombres = ofertas.to_h { |oferta| [oferta['gcal'], oferta['calendar_name']] }
    unidades.map { |gcal, descripcion| "#{nombres[gcal] || 'Unidad'}: #{descripcion}" }.join("\n")
  end

  def date_line(caso, datos)
    folio = "Caso #{caso.folio.presence || caso.id}"
    return folio if datos['date'].blank?

    fecha = Date.iso8601(datos['date'])
    "#{day(fecha)} · #{folio}"
  end

  def state_line(caso, plan)
    estado = STATES.fetch(caso.metadata['estado'].to_s, DEFAULT_STATE)
    pedida = plan&.exact && plan.offers.present? ? " (la de las #{plan.requested.in_time_zone(@timezone).strftime('%H:%M')} es la que pediste)" : ''
    "Estado: #{estado}#{pedida}"
  end

  # «a las 12:00 no hay; estas son las más cercanas», «esa fecha ya pasó»… La de la hora libre ya va en el estado.
  def note_line(plan)
    return nil if plan&.note.blank? || plan.exact

    "#{plan.note[0].upcase}#{plan.note[1..]}."
  end

  # Las opciones (tabla), o el horario ya apartado.
  def schedule_line(plan, ofertas, held, sync_failed)
    return table(ofertas, plan.requested) if ofertas.any?

    held && held_line(held, sync_failed)
  end

  def missing_line(missing)
    "Falta: #{missing.join(', ')}" if missing.any?
  end

  HEADER = %w[Op Horario Unidad].freeze

  def table(ofertas, pedido)
    filas = ofertas.map { |oferta| [oferta['code'].to_s[/[A-Z]\z/i].to_s.upcase, schedule(oferta, pedido), oferta['calendar_name'].to_s] }
    return filas.map { |fila| fila.compact_blank.join(' · ') }.join("\n") unless monospace?

    "```\n#{aligned([HEADER] + filas).join("\n")}\n```"
  end

  # Op en 4, el horario a lo ancho del más largo + 2; ningún renglón pasa de WIDTH.
  def aligned(renglones)
    ancho = renglones.map { |fila| fila[1].size }.max + 2
    renglones.map { |op, horario, unidad| "#{op.ljust(4)}#{horario.ljust(ancho)}#{unidad}"[0, WIDTH].rstrip }
  end

  # Mismo día que lo pedido: solo la hora; otro día: el día también. Una renta: del primero al último día.
  def schedule(oferta, pedido)
    inicio = Time.zone.parse(oferta['slot']).in_time_zone(@timezone)
    fin = Time.zone.parse(oferta['end_time']).in_time_zone(@timezone)
    return "#{day_month(inicio)}-#{day_month(fin - 1.day)}" if oferta['all_day']

    horas = "#{inicio.strftime('%H:%M')}-#{fin.strftime('%H:%M')}"
    pedido && inicio.to_date == pedido.in_time_zone(@timezone).to_date ? horas : "#{short_day(inicio)} #{horas}"
  end

  def held_line(held, sync_failed)
    aviso = sync_failed ? ' (un asesor confirma el horario)' : ''
    unidad = held['calendar_name'].present? ? " · #{held['calendar_name']}" : ''
    return "Periodo: #{schedule(held, nil)}#{unidad}#{aviso}" if held['all_day']

    inicio = Time.zone.parse(held['slot']).in_time_zone(@timezone)
    fin = Time.zone.parse(held['end_time']).in_time_zone(@timezone)
    "Horario: #{inicio.strftime('%H:%M')}-#{fin.strftime('%H:%M')}#{unidad}#{aviso}"
  end

  # Un servicio ya apartado que se vuelve a mostrar: su horario sale de la tarea.
  def meeting_slot(caso)
    tarea = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    return nil if tarea.nil? || tarea.cancelled?

    clave = caso.metadata[ContactTrackings::ServiceRequests::Fields::ASSIGNED_KEY]
    { 'slot' => tarea.starts_at.iso8601, 'end_time' => tarea.ends_at.iso8601,
      'calendar_name' => clave.present? ? caso.custom_attributes.to_h[clave] : nil }
  end

  def label(caso, datos)
    datos['label'].presence || caso.title
  end

  def day(fecha)
    "#{ContactTrackings::ServiceRequests::Turn::DAYS[fecha.wday]} #{fecha.day} #{ContactTrackings::ServiceRequests::Turn::MONTHS[fecha.month - 1]}"
  end

  def day_month(time)
    "#{time.day} #{ContactTrackings::ServiceRequests::Turn::MONTHS[time.month - 1]}"
  end

  def short_day(time)
    "#{ContactTrackings::ServiceRequests::Turn::DAYS[time.wday]} #{time.day}"
  end
end
