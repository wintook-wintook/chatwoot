# proyecto@metricas_casos
#
# Velocidad por etapa (#4) y oportunidades estancadas (#6): a diferencia del resto
# de los reportes de Casos, acá SÍ hace falta reconstruir historial — cuánto tiempo
# pasó cada ticket en cada `status`. Se usa `status` (canónico, siempre registrado
# en case_events en cada transición) en vez de `case_type_column_id`: los cambios
# de columna que cruzan de estado (`move_across_state`) NO dejan `column_changed`
# en el log — solo el status queda con historial completo y confiable.
class V2::Reports::Cases::StageDurationBuilder < V2::Reports::Cases::BaseBuilder
  # Tipos de evento que `CaseTicket#transition!`/`#escalate!` usan para marcar un
  # cambio de status (ver `event_type_for_transition`). `escalated` puede o no
  # traer status nuevo (una escalada de nivel sin cambiar status no cuenta acá) —
  # por eso el filtro real es `payload['to']` presente, no la sola pertenencia
  # a esta lista.
  TRANSITION_EVENT_TYPES = %w[assigned in_diagnosis escalated resolved validating closed reopened status_changed].freeze
  OPEN_STATUSES = (CaseTicket.statuses.keys - %w[closed cancelled]).freeze
  SECONDS_PER_DAY = 86_400.0
  DEFAULT_THRESHOLD_DAYS = 3

  # Promedio de tiempo (en días) que los tickets pasaron en cada status, contando
  # solo intervalos YA CERRADOS (el ticket salió de ese status hacia otro) — el
  # tiempo en el status ACTUAL, todavía corriendo, no entra acá (ver `#stalled`).
  def velocity
    durations_by_status = Hash.new { |h, k| h[k] = [] }
    tickets_with_checkpoints.each do |_ticket, checkpoints|
      checkpoints.each_cons(2) do |(from_time, from_status), (to_time, _to_status)|
        durations_by_status[from_status] << (to_time - from_time)
      end
    end
    durations_by_status.map { |status, durations| stage_row(status, durations) }.sort_by { |row| -row[:avg_days] }
  end

  # Tickets abiertos cuyo tiempo en el status ACTUAL supera el umbral — la otra
  # cara de `#velocity`: en vez de promediar duraciones terminadas, mide la que
  # sigue corriendo ahora mismo.
  def stalled(threshold_days: DEFAULT_THRESHOLD_DAYS)
    threshold_seconds = threshold_days.to_f * SECONDS_PER_DAY
    now = Time.current

    rows = tickets_with_checkpoints.filter_map do |ticket, checkpoints|
      next unless OPEN_STATUSES.include?(ticket.status)

      entered_at, = checkpoints.last
      stalled_seconds = now - entered_at
      next if stalled_seconds < threshold_seconds

      stalled_row(ticket, stalled_seconds)
    end
    rows.sort_by { |row| -row[:stalled_days] }
  end

  private

  def stage_row(status, durations)
    {
      status: status,
      avg_days: (durations.sum / durations.size / SECONDS_PER_DAY).round(1),
      count: durations.size
    }
  end

  def stalled_row(ticket, stalled_seconds)
    {
      id: ticket.id,
      folio: ticket.folio,
      title: ticket.title,
      status: ticket.status,
      assignee_id: ticket.assignee_id,
      assignee_name: ticket.assignee&.name,
      stalled_days: (stalled_seconds / SECONDS_PER_DAY).round(1)
    }
  end

  # Por ticket: [[timestamp, status], ...] ordenado — arranca en 'open' al crearse
  # y suma un checkpoint por cada evento de transición con status nuevo real.
  def tickets_with_checkpoints
    @tickets_with_checkpoints ||= tickets.map { |ticket| [ticket, checkpoints_for(ticket)] }
  end

  def checkpoints_for(ticket)
    checkpoints = [[ticket.created_at, 'open']]
    (events_by_ticket[ticket.id] || []).each do |event|
      to_status = event.payload['to']
      checkpoints << [event.created_at, to_status] if to_status.present?
    end
    checkpoints
  end

  def tickets
    @tickets ||= scoped_tickets.includes(:assignee).to_a
  end

  def events_by_ticket
    @events_by_ticket ||= CaseEvent.where(case_ticket_id: tickets.map(&:id), event_type: TRANSITION_EVENT_TYPES)
                                   .order(:created_at).group_by(&:case_ticket_id)
  end
end
