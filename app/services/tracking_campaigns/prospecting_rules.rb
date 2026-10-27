# frozen_string_literal: true

# ================================================================================
# prospeccion V3 — LAS REGLAS DE UNA CAMPAÑA DE PROSPECCIÓN
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§10.2, §10.3 V3, D13).
#
#   · Tope diario obligatorio (1..500; la pantalla sugiere 30): no quemar el dominio.
#   · Siempre días hábiles y horario de atención (respect_working_hours = true).
#   · En correo, asunto obligatorio (F1).
#
# Por lote, el tope REPARTE a los contactos en días hábiles (TrackingCampaigns::Enroll);
# en continua, como siempre, el que pasa del tope del día queda omitido.
# Lo usan la API por lote (BulkAssignService) y la continua (TrackingCampaignContinuousParams).
# ================================================================================
module TrackingCampaigns::ProspectingRules
  DEFAULT_DAILY_CAP = 30
  MAX_DAILY_CAP = 500

  module_function

  def error_for(purpose:, daily_cap:, email_subject:, inbox:)
    return unless purpose.to_s == 'prospecting'
    return 'En Prospección el tope diario es obligatorio.' if daily_cap.blank?
    return "El tope diario va de 1 a #{MAX_DAILY_CAP}." unless (1..MAX_DAILY_CAP).cover?(daily_cap.to_i)

    'En Prospección por correo el asunto es obligatorio.' if inbox&.email? && email_subject.to_s.strip.blank?
  end
end
