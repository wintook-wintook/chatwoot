# frozen_string_literal: true

# ================================================================================
# prospeccion V2 — EL PROSPECTO RESPONDIÓ: YA NO SE LE MANDAN TOQUES
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§9 F4, §10 V2, D10).
#
#   Antes: respondía y al rato le llegaba «¿tienes alguna duda?» como si nada.
#   Ahora, en cuanto entra su mensaje:
#     · el siguiente toque se mueve a 3 días hábiles (nunca sábado ni domingo), a la
#       misma hora, en la zona horaria de la bandeja;
#     · queda como mucho UN toque más (el de recuperación, si deja de contestar);
#     · cada respuesta nueva vuelve a empujar la fecha.
#   La IA sigue contestando como siempre. Mover scheduled_for basta: el callback
#   reschedule_job_if_needed cancela el job programado y agenda el nuevo.
#
# Solo toca seguimientos que esperan su siguiente toque (pending / scheduled): uno en
# ejecución (active), pausado o terminado se queda como está.
# ================================================================================
module ContactTrackings::ProspectReply
  RECOVERY_BUSINESS_DAYS = 3
  WAITING_STATUSES = %w[pending scheduled].freeze

  module_function

  def call(tracking, at: Time.current)
    return false unless WAITING_STATUSES.include?(tracking.status)

    remaining = [tracking.max_attempts, tracking.attempt_count + 1].min
    ok = tracking.update(scheduled_for: recovery_at(at, tracking.inbox), max_attempts: remaining)
    Rails.logger.warn "[ProspectReply] Tracking ##{tracking.id}: #{tracking.errors.full_messages.join(', ')}" unless ok
    ok
  end

  def recovery_at(from, inbox)
    time = from.in_time_zone(inbox&.timezone.presence || 'UTC')
    days = 0
    while days < RECOVERY_BUSINESS_DAYS
      time += 1.day
      days += 1 unless time.saturday? || time.sunday?
    end
    time
  end
end
