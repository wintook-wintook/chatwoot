# frozen_string_literal: true

# @tickets_cases F3 — Reconciliación perezosa (plan §5): al ABRIR la pestaña
# Reuniones se relee desde Google lo que pudo cambiar allá.
#
# Es estrictamente de LECTURA: si hay conflicto, Google gana en fecha/hora y
# cancelación, porque es donde el humano acabó de tocar. Nunca escribe hacia
# Google, nunca crea notas (§5.2) — solo actualiza filas y registra
# `meeting_updated` con `origin: :system` y `source: 'google'`.
#
# Costo acotado: solo reuniones FUTURAS y no canceladas, tope de 25 por
# lectura y throttle de 60 s por ticket (`reconciled_at`).
class Cases::Meetings::ReconcileService
  MAX_MEETINGS = 25
  THROTTLE = 60.seconds

  def initialize(ticket)
    @ticket = ticket
  end

  def perform
    pending = candidates
    return 0 if pending.empty?

    reconcile_all(pending)
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] reconciliación del ticket #{@ticket.id}: #{e.message}")
    0
  end

  private

  # Las ocurrencias de una serie NO se consultan por su id de instancia (§5.1):
  # se resuelven todas juntas contra el maestro, y de paso sale más barato.
  def reconcile_all(pending)
    loose, in_series = pending.partition { |m| m.case_meeting_series_id.blank? }
    touched = loose.count { |m| reconcile_loose(m) }
    in_series.group_by(&:case_meeting_series_id).each do |series_id, meetings|
      touched += reconcile_series(series_id, meetings)
    end
    touched
  end

  # Futuras, vivas, con evento en Google y organizador conectado; y no
  # releídas en el último minuto.
  def candidates
    @ticket.case_meetings
           .active
           .where.not(google_event_id: [nil, ''])
           .where(starts_at: Time.current..)
           .where('reconciled_at IS NULL OR reconciled_at < ?', THROTTLE.ago)
           .order(:starts_at)
           .limit(MAX_MEETINGS)
           .select { |m| service_for(m).present? }
  end

  # ── Reunión suelta: se consulta por su propio id ──────────────────────
  def reconcile_loose(meeting)
    event = service_for(meeting).get_event(meeting.google_event_id, calendar_id: calendar_id(meeting))
    stamp(meeting)

    # Un evento que ya no existe SÍ es una cancelación real cuando la reunión
    # no pertenece a ninguna serie.
    return cancel_from_google(meeting) if event == :already_gone || event['status'] == 'cancelled'

    apply_event(meeting, event)
  rescue StandardError => e
    note_error(meeting, e)
    false
  end

  # ── Serie: una sola llamada resuelve todas sus ocurrencias (§5.1) ─────
  def reconcile_series(series_id, meetings)
    # Sellar ANTES de llamar a Google: si la consulta falla o devuelve algo raro,
    # el throttle igual aplica y no se repregunta en cada lectura de la pestaña.
    meetings.each { |m| stamp(m) }
    instances = master_instances(series_id, meetings.first)
    return 0 if instances.nil?

    # El maestro desapareció: la serie sí se borró en Google.
    if instances == :already_gone
      meetings.each { |m| cancel_from_google(m) }
      return meetings.size
    end

    match_instances(meetings, instances)
  rescue StandardError => e
    meetings.each { |m| note_error(m, e) }
    0
  end

  # Instancias del evento MAESTRO. nil = no hay nada que reconciliar.
  def master_instances(series_id, sample)
    series = CaseMeetingSeries.find_by(id: series_id)
    return nil if series.nil? || series.google_event_id.blank?

    service_for(sample).list_instances(
      series.google_event_id,
      calendar_id: calendar_id(sample)
    )
  end

  # Re-empareja nuestras filas con las instancias de Google por
  # `originalStartTime` (estable aunque se muevan) y, si no, por orden.
  def match_instances(meetings, instances)
    live = instances.reject { |i| i['status'] == 'cancelled' }
                    .sort_by { |i| i.dig('start', 'dateTime').to_s }
    by_original = live.index_by { |i| i.dig('originalStartTime', 'dateTime') }
    leftovers = live.dup
    touched = 0

    meetings.sort_by(&:starts_at).each do |meeting|
      touched += 1 if apply_instance(meeting, instance_for(meeting, by_original, live, leftovers), leftovers)
    end
    touched
  end

  # Una fila contra su instancia: sin instancia viva, esa ocurrencia sí se canceló.
  def apply_instance(meeting, instance, leftovers)
    return cancel_from_google(meeting) if instance.nil?

    leftovers.delete(instance)
    apply_event(meeting, instance)
  end

  # `originalStartTime` es el ancla estable: sobrevive a que muevan la ocurrencia.
  # Si ya no coincide, se cae al id guardado y, en último término, al orden
  # cronológico — consumiendo `leftovers`, que ya viene ordenado y sin los ya
  # emparejados (indexar por posición desalineaba la última ocurrencia).
  def instance_for(meeting, by_original, live, leftovers)
    by_original[meeting.starts_at&.utc&.iso8601] ||
      live.find { |i| i['id'] == meeting.google_event_id } ||
      leftovers.first
  end

  # Escritura directa a propósito: la reconciliación refleja lo que YA pasó en
  # Google; no debe disparar validaciones ni las firmas derivadas del modelo.
  # rubocop:disable Rails/SkipsModelValidations
  def write!(meeting, attrs)
    meeting.update_columns(attrs.merge(updated_at: Time.current))
  end
  # rubocop:enable Rails/SkipsModelValidations

  # ── Escritura local ───────────────────────────────────────────────────
  # Google gana en fecha/hora. Si cambió, se anota en la bitácora con el
  # rastro de que vino de fuera (§5.2).
  def apply_event(meeting, event)
    starts = parse_time(event.dig('start', 'dateTime'))
    ends   = parse_time(event.dig('end', 'dateTime'))
    return false if starts.nil?

    moved = meeting.starts_at.to_i != starts.to_i
    attrs = { starts_at: starts, sync_status: CaseMeeting.sync_statuses[:synced], sync_error: nil }
    attrs[:ends_at] = ends if ends
    # El id de instancia cambia si movieron la serie completa: se re-liga.
    attrs[:google_event_id] = event['id'] if event['id'].present?
    url = GoogleCalendarService.meet_url_from(event)
    attrs[:meeting_url] = url if url.present?

    from = meeting.starts_at
    write!(meeting, attrs)
    log_update(meeting, from, starts) if moved
    moved
  end

  def cancel_from_google(meeting)
    return false if meeting.cancelled?

    write!(meeting,
           status: CaseMeeting.statuses[:cancelled],
           cancelled_at: Time.current,
           sync_status: CaseMeeting.sync_statuses[:synced])
    log_cancel(meeting)
    true
  end

  def stamp(meeting)
    write!(meeting, reconciled_at: Time.current)
  end

  def note_error(meeting, error)
    Rails.logger.warn("[GestorTickets] reconciliar reunión #{meeting.id}: #{error.message}")
    write!(meeting,
           sync_status: CaseMeeting.sync_statuses[:failed],
           sync_error: error.message.to_s.truncate(500))
  end

  # ── Bitácora ──────────────────────────────────────────────────────────
  def log_update(meeting, from, to)
    @ticket.case_events.create!(
      account_id: @ticket.account_id,
      event_type: :meeting_updated,
      origin: :system, # no fue un agente actuando en MGCI
      case_task: meeting.case_task,
      payload: {
        meeting_id: meeting.id, folio: meeting.folio, title: meeting.title,
        source: 'google', from: from, to: to, scope: 'one'
      }
    )
  end

  def log_cancel(meeting)
    @ticket.case_events.create!(
      account_id: @ticket.account_id,
      event_type: :meeting_cancelled,
      origin: :system,
      case_task: meeting.case_task,
      payload: {
        meeting_id: meeting.id, folio: meeting.folio, title: meeting.title,
        source: 'google', starts_at: meeting.starts_at, scope: 'one'
      }
    )
  end

  # ── Auxiliares ────────────────────────────────────────────────────────
  def service_for(meeting)
    @services ||= {}
    return @services[meeting.organizer_id] if @services.key?(meeting.organizer_id)

    mirror = Cases::Meetings::GoogleMirrorService.new(meeting)
    @services[meeting.organizer_id] =
      mirror.mirrorable? ? GoogleCalendarService.new(mirror.integration) : nil
  end

  def calendar_id(meeting)
    meeting.google_calendar_id.presence || 'primary'
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value)
  end
end
