# frozen_string_literal: true

# ================================================================================
# @tickets_cases F7 — Procesa un aviso de push de Google Calendar (plan §12.3)
# ================================================================================
# El ping solo dice "algo cambió". Aquí se pregunta QUÉ cambió con el `sync_token`
# incremental y se aplica **la misma lógica de §5.1/§5.2**: el webhook no
# reimplementa nada, solo cambia quién dispara la reconciliación — antes era
# "alguien abrió la pestaña", ahora es "Google avisó". `ReconcileService` se
# reutiliza tal cual, incluido el camino de series contra el maestro.
#
# ⚠️ PRIVACIDAD (§12.4): `events.watch` es por CALENDARIO, no por evento, así que
# llegan avisos de los eventos personales del agente. Todo evento cuyo id no sea
# una reunión nuestra se **descarta en memoria**: no se persiste, no se registra
# en `case_events` y **no se escribe en logs** — tampoco el cuerpo de la respuesta.
# ================================================================================

class Cases::CalendarPushJob < ApplicationJob
  queue_as :low

  def perform(integration_id)
    integration = UserCalendarIntegration.find_by(id: integration_id)
    return if integration.nil? || integration.sync_token.blank?

    result = GoogleCalendarService.new(integration).list_events_incremental(sync_token: integration.sync_token)
    # 410 GONE: el cursor caducó. No es fatal, es "vuelve a empezar" (§12.7.5):
    # se pide un token nuevo y la reconciliación perezosa cubre el hueco.
    return reset_sync_token(integration) if result == :gone

    items, next_token = result
    reconcile_our_meetings(integration, items)
    save_sync_token(integration, next_token)
  rescue StandardError => e
    # Nunca se loguea el contenido del calendario, solo el mensaje del fallo.
    Rails.logger.error("[GestorTickets] CalendarPushJob #{integration_id}: #{e.class}: #{e.message}")
  end

  private

  # Cursor de Google: metadata del sistema, sin validaciones que aplicar.
  # rubocop:disable Rails/SkipsModelValidations
  def save_sync_token(integration, token)
    integration.update_columns(sync_token: token) if token.present?
  end
  # rubocop:enable Rails/SkipsModelValidations

  # De todos los eventos que cambiaron, solo nos importan los que SON nuestros.
  # El resto ni se cuenta ni se nombra.
  def reconcile_our_meetings(integration, items)
    ids = items.filter_map { |e| e['id'].presence }
    return if ids.empty?

    tickets = affected_tickets(integration.account_id, ids)
    tickets.each do |ticket|
      # Se salta el throttle a propósito: el aviso ES el disparador.
      ticket.case_meetings.where(google_event_id: ids).update_all(reconciled_at: nil) # rubocop:disable Rails/SkipsModelValidations
      Cases::Meetings::ReconcileService.new(ticket).perform
    end
  end

  # Tickets con reuniones nuestras entre los ids que cambiaron. Una ocurrencia de
  # serie puede haber cambiado de id (§5.1), así que también se mira la serie por
  # su evento maestro.
  def affected_tickets(account_id, ids)
    meeting_tickets = CaseMeeting.where(account_id: account_id, google_event_id: ids).distinct.pluck(:case_ticket_id)
    series_tickets = CaseMeetingSeries.where(account_id: account_id, google_event_id: ids).distinct.pluck(:case_ticket_id)
    CaseTicket.where(id: (meeting_tickets + series_tickets).uniq)
  end

  def reset_sync_token(integration)
    save_sync_token(integration, GoogleCalendarService.new(integration).initial_sync_token)
  end
end
