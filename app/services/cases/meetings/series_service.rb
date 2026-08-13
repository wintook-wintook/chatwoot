# frozen_string_literal: true

# @tickets_cases F4 — Alta y ciclo de vida de una SERIE de reuniones (plan §4.3).
#
# El flujo es el del plan, sin reimplementar el calendario: se crea el maestro
# recurrente en Google, se le piden sus instancias y se persiste una fila
# `case_meetings` por instancia. Si Google no está disponible, las fechas se
# calculan localmente con `RRuleBuilder#expand` y las ocurrencias nacen
# `local_only`, reintentables después.
#
#   POST /series
#       ├─► RRuleBuilder → "RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8"
#       ├─► case_meeting_series (BD)        ── siempre, aunque Google falle
#       ├─► create_event(recurrence:, with_meet: true)  ── 1 evento maestro
#       └─► list_instances(maestro) → N × case_meetings
class Cases::Meetings::SeriesService
  def initialize(series, actor: nil)
    @series = series
    @ticket = series.case_ticket
    @actor  = actor
  end

  # Crea el maestro en Google (si se puede) y materializa las ocurrencias.
  # Devuelve las reuniones creadas.
  def generate!
    @series.update!(recurrence_rule: builder.rule)
    event = mirror_master
    event ? persist_from_google(event) : persist_locally
  end

  # @tickets_cases F5 (§11.1) — la serie se extendió (el vencimiento de la tarea
  # se movió): se recalcula el RRULE y se crean SOLO las ocurrencias que faltan,
  # sin tocar las que ya existen. Cada ocurrencia nueva le escribe al cliente, por
  # eso nunca se dispara sola.
  def regenerate_missing!
    @series.update!(recurrence_rule: builder.rule)
    existentes = @series.case_meetings.pluck(:starts_at).map(&:to_i)
    duration = builder.duration
    nuevas = builder.expand.reject { |start| existentes.include?(start.to_i) }
    push_recurrence if mirror.mirrorable? && @series.google_event_id.present?
    nuevas.map { |start| build_meeting(start, start + duration) }
  end

  # Trunca la serie para conservar hasta `last_kept` y borrar el resto (§11.2).
  # Un solo PATCH sobre el maestro = UN solo aviso al cliente, en vez de N
  # cancelaciones. Si la serie no tiene ninguna realizada, el llamador debería
  # cancelar el maestro completo (DELETE) en vez de truncar.
  def truncate!(last_kept)
    rule = Cases::Meetings::RRuleBuilder.truncate_rule(@series, last_kept)
    dropped_ids = @series.case_meetings.active.where('starts_at > ?', last_kept).pluck(:id)

    push_truncation(rule) if mirror.mirrorable? && @series.google_event_id.present?
    # `until_at` guarda el MISMO corte que viaja en el RRULE (un minuto después de
    # la última conservada): así la fila y Google dicen lo mismo, y truncar dejando
    # solo la primera ocurrencia no choca con la validación `until_at > starts_at`.
    @series.update!(recurrence_rule: rule, until_at: last_kept + 1.minute, count: nil)
    CaseMeeting.where(id: dropped_ids).find_each { |m| m.update!(status: :cancelled) }
    dropped_ids.size
  end

  private

  def builder
    @builder ||= Cases::Meetings::RRuleBuilder.new(@series)
  end

  # Reunión de referencia para resolver la integración del organizador: no existe
  # todavía ninguna fila, así que se arma una en memoria.
  def mirror
    @mirror ||= Cases::Meetings::GoogleMirrorService.new(sample_meeting)
  end

  def sample_meeting
    CaseMeeting.new(
      account_id: @series.account_id, case_ticket: @ticket,
      organizer_id: @series.organizer_id, title: @series.title,
      starts_at: @series.starts_at, ends_at: @series.ends_at
    )
  end

  # Crea el evento MAESTRO recurrente. Devuelve el evento o nil si no hay espejo.
  def mirror_master
    return nil unless mirror.mirrorable?

    event = calendar.create_event(
      calendar_id: 'primary',
      summary: @series.title,
      description: @series.description,
      start_time: @series.starts_at,
      end_time: @series.ends_at,
      attendees: mirror.attendees,
      recurrence: [@series.recurrence_rule],
      with_meet: true,
      send_updates: 'all'
    )
    @series.update!(google_event_id: event['id'], google_calendar_id: 'primary',
                    sync_status: :synced, sync_error: nil)
    event
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] maestro de la serie #{@series.id}: #{e.message}")
    @series.update!(sync_status: :failed, sync_error: e.message.to_s.truncate(500))
    nil
  end

  # Google materializa las instancias; nosotros solo las guardamos.
  def persist_from_google(event)
    instances = calendar.list_instances(event['id'])
    return persist_locally if instances == :already_gone || instances.blank?

    meet_url = GoogleCalendarService.meet_url_from(event)
    instances.reject { |i| i['status'] == 'cancelled' }
             .first(Cases::Meetings::RRuleBuilder::MAX_OCCURRENCES)
             .map { |i| build_meeting(instance_start(i), instance_end(i), google_event_id: i['id'], meet_url: meet_url) }
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] instancias de la serie #{@series.id}: #{e.message}")
    persist_locally
  end

  # Modo degradado: las fechas salen del cálculo local, sin `google_event_id`.
  # La serie queda reintentable desde la fila ("Reintentar sincronización").
  def persist_locally
    duration = builder.duration
    @series.update!(sync_status: @series.sync_failed? ? :failed : :local_only)
    builder.expand.map { |start| build_meeting(start, start + duration) }
  end

  def build_meeting(starts_at, ends_at, google_event_id: nil, meet_url: nil)
    @series.case_meetings.create!(
      account_id: @series.account_id,
      case_ticket: @ticket,
      case_task_id: @series.case_task_id,
      organizer_id: @series.organizer_id,
      title: @series.title,
      description: @series.description,
      starts_at: starts_at,
      ends_at: ends_at,
      time_zone: @series.time_zone,
      attendee_emails: series_attendees,
      google_event_id: google_event_id,
      google_calendar_id: google_event_id ? 'primary' : nil,
      meeting_url: meet_url,
      sync_status: google_event_id ? :synced : :local_only
    )
  end

  # Los invitados "del cliente" de la serie: se guardan en cada ocurrencia para
  # que la fila muestre a quién se citó, igual que en una reunión suelta.
  def series_attendees
    contact_email = @ticket.contact&.email
    contact_email.present? ? [contact_email] : []
  end

  # Empuja el RRULE nuevo al maestro (extensión de la serie). Un solo PATCH.
  def push_recurrence
    calendar.update_event(
      @series.google_event_id,
      calendar_id: @series.google_calendar_id.presence || 'primary',
      start_time: @series.starts_at,
      end_time: @series.ends_at,
      recurrence: [@series.recurrence_rule],
      send_updates: 'all'
    )
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] extender la serie #{@series.id}: #{e.message}")
    @series.update!(sync_status: :failed, sync_error: e.message.to_s.truncate(500))
  end

  def push_truncation(rule)
    calendar.update_event(
      @series.google_event_id,
      calendar_id: @series.google_calendar_id.presence || 'primary',
      start_time: @series.starts_at,
      end_time: @series.ends_at,
      recurrence: [rule],
      send_updates: 'all'
    )
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] truncar la serie #{@series.id}: #{e.message}")
    @series.update!(sync_status: :failed, sync_error: e.message.to_s.truncate(500))
  end

  def calendar
    @calendar ||= GoogleCalendarService.new(mirror.integration)
  end

  def instance_start(instance)
    Time.zone.parse(instance.dig('start', 'dateTime').to_s)
  end

  def instance_end(instance)
    Time.zone.parse(instance.dig('end', 'dateTime').to_s) || (instance_start(instance) + builder.duration)
  end
end
