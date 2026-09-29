# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — APARTADO → CONFIRMADO (pieza 4, 26/09/2026)
# ================================================================================
# En SSUSA una solicitud no es un servicio: «confirmen disponibilidad» aparta, y solo «le
# confirmamos el servicio» o el pago lo dejan en firme. Antes, en cuanto el cliente elegía
# un horario, la cita quedaba en firme.
#
#   @agendar_calendar(modo=tentativo)      el evento se crea «[TENTATIVO] …» y el seguimiento
#                                          queda appointment_status = tentative
#   @confirmar_servicio                    (ruta de confirmación) → confirmed: quita
#                                          «[TENTATIVO]» del evento
#   @confirmar_servicio(requiere=pago)     → pending_payment: pide el pago; lo deja en firme
#                                          una persona con la etiqueta «pago_confirmado»
#                                          (ServiceConfirmationListener)
#
# El evento tentativo SÍ ocupa el horario: nadie más lo puede apartar.
# ================================================================================

class ContactTrackings::ServiceConfirmation
  DIRECTIVE_RE = /@confirmar_servicio\b(?:\s*\(([^)]*)\))?/i
  TENTATIVE_PREFIX = '[TENTATIVO] '
  PAID_LABEL = 'pago_confirmado'
  OPEN_STATUSES = %w[tentative pending_payment].freeze

  def self.requires_payment?(text)
    text.to_s[DIRECTIVE_RE, 1].to_s.gsub(/\s/, '').casecmp?('requiere=pago')
  end

  def initialize(tracking)
    @tracking = tracking
  end

  def open?
    OPEN_STATUSES.include?(@tracking.appointment_status) && @tracking.appointment_event_id.present?
  end

  def pending_payment?
    @tracking.appointment_status == 'pending_payment'
  end

  def mark_pending_payment!
    @tracking.update!(appointment_status: 'pending_payment')
  end

  # Quita «[TENTATIVO]» del evento y lo deja en firme. false si Google no respondió: el
  # servicio NO se da por confirmado sin el calendario.
  def confirm!
    rename_event
    @tracking.update!(appointment_status: 'confirmed', outcome: 'appointment')
    true
  rescue StandardError => e
    Rails.logger.error "[ServiceConfirmation] ❌ No se pudo confirmar el evento #{@tracking.appointment_event_id}: #{e.message}"
    false
  end

  # «lunes 28 de septiembre a las 09:00»
  def when_text(timezone)
    return 'tu servicio' if @tracking.appointment_at.blank?

    at = @tracking.appointment_at.in_time_zone(timezone)
    "#{ContactTrackings::AmbiguousDate.note(at, timezone).delete_prefix('Entiendo que es el ')} a las #{at.strftime('%H:%M')}"
  end

  private

  def rename_event
    integration = UserCalendarIntegration.find(@tracking.appointment_calendar_id)
    calendar_id = @tracking.appointment_calendar_gid.presence || 'primary'
    service = GoogleCalendarService.new(integration)
    evento = service.get_event(@tracking.appointment_event_id, calendar_id: calendar_id)
    raise 'el evento ya no existe' if evento == :already_gone

    titulo = evento['summary'].to_s.delete_prefix(TENTATIVE_PREFIX)
    service.rename_event(@tracking.appointment_event_id, calendar_id: calendar_id, summary: titulo)
  end
end
