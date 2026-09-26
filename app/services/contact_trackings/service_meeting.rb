# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LA TAREA AGENDADA DE UN SERVICIO (pieza 5, F0, 26/09/2026)
# ================================================================================
# Con @solicitudes cada servicio es un caso (CaseTicket) y su horario es una Tarea agendada
# (CaseMeeting) en el calendario de SU equipo. Plan: docs/solicitudes_multiservicio_plan.md
#
# El espejo de Tickets (Cases::Meetings::GoogleMirrorService#create) crea liga de Meet y
# manda invitaciones: sirve para una reunión con el cliente, no para apartar una grúa. Aquí
# el evento se crea directo, sin Meet ni correos, y la fila queda `synced` con su
# google_event_id: mover y cancelar desde Tickets siguen usando el espejo de siempre.
#
#   hold!     aparta: «[TENTATIVO] …», tentative = true
#   confirm!  en firme: quita «[TENTATIVO]» del evento y de la tarea
#   cancel!   cancela la tarea y borra el evento
# ================================================================================

class ContactTrackings::ServiceMeeting
  PREFIX = ContactTrackings::ServiceConfirmation::TENTATIVE_PREFIX

  # slot: el de AvailabilitySlotService (slot, end_time, calendar_integration_id, google_calendar_id).
  def self.hold!(ticket:, slot:, title:, timezone:)
    integration = UserCalendarIntegration.find(slot[:calendar_integration_id])
    meeting = ticket.case_meetings.create!(
      account_id: ticket.account_id, organizer_id: integration.user_id, title: "#{PREFIX}#{title}".truncate(255),
      starts_at: slot[:slot], ends_at: slot[:end_time], google_calendar_id: slot[:google_calendar_id],
      time_zone: timezone, notify_client: false, tentative: true, sync_status: :pending
    )
    new(meeting).create_event(integration)
    meeting
  end

  def initialize(meeting)
    @meeting = meeting
  end

  def create_event(integration)
    evento = GoogleCalendarService.new(integration).create_event(
      calendar_id: calendar_id, summary: @meeting.title, description: @meeting.case_ticket.description,
      start_time: @meeting.starts_at, end_time: @meeting.ends_at, send_updates: 'none'
    )
    write!(google_event_id: evento['id'], sync_status: CaseMeeting.sync_statuses[:synced], sync_error: nil)
  rescue StandardError => e
    Rails.logger.error "[ServiceMeeting] ❌ evento de la tarea #{@meeting.id}: #{e.message}"
    write!(sync_status: CaseMeeting.sync_statuses[:failed], sync_error: e.message.to_s.truncate(500))
  end

  # false si Google no respondió: el servicio NO se da por confirmado sin el calendario.
  def confirm!
    titulo = @meeting.title.delete_prefix(PREFIX)
    GoogleCalendarService.new(integration).rename_event(@meeting.google_event_id, summary: titulo, calendar_id: calendar_id)
    @meeting.update!(title: titulo, tentative: false)
    true
  rescue StandardError => e
    Rails.logger.error "[ServiceMeeting] ❌ confirmar la tarea #{@meeting.id}: #{e.message}"
    false
  end

  def cancel!
    @meeting.update!(status: :cancelled)
    Cases::Meetings::GoogleMirrorService.new(@meeting).cancel
  end

  private

  def integration
    UserCalendarIntegration.find_by!(account_id: @meeting.account_id, user_id: @meeting.organizer_id)
  end

  def calendar_id
    @meeting.google_calendar_id.presence || 'primary'
  end

  # Estado del espejo = metadata del sistema: sin validaciones ni callbacks (como el espejo de Tickets).
  def write!(attrs)
    @meeting.update_columns(attrs.merge(updated_at: Time.current)) # rubocop:disable Rails/SkipsModelValidations
  end
end
