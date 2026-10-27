# frozen_string_literal: true

# ================================================================================
# LAS REGLAS DE UNA CAMPAÑA — por canal, no por tipo (§10.12 U1, D21)
# ================================================================================
# Antes eran las de Prospección (V3); desde §10.12 hay una sola campaña:
#
#   correo  → tope diario obligatorio (1..500; la pantalla sugiere 30): no quemar el buzón
#           → asunto obligatorio (sin asunto sale «[#N] Nuevos mensajes…»)
#   otros   → tope opcional; si viene, de 1 a 500 (WhatsApp ya tiene los límites de Meta)
#
# Días hábiles y horario: casilla de la campaña, prendida por omisión.
# Por lote, el tope REPARTE a los contactos en días hábiles (TrackingCampaigns::Enroll);
# en continua, el que pasa del tope del día queda omitido.
# Lo usan la API por lote (BulkAssignService) y la continua (TrackingCampaignContinuousParams).
# ================================================================================
module TrackingCampaigns::CampaignRules
  DEFAULT_DAILY_CAP = 30
  MAX_DAILY_CAP = 500

  module_function

  def error_for(daily_cap:, email_subject:, inbox:)
    return email_error(daily_cap, email_subject) if inbox&.email?
    return if daily_cap.blank?

    cap_range_error(daily_cap)
  end

  def email_error(daily_cap, email_subject)
    return 'En campañas por correo el tope diario es obligatorio.' if daily_cap.blank?
    return cap_range_error(daily_cap) if cap_range_error(daily_cap)

    'En campañas por correo el asunto es obligatorio.' if email_subject.to_s.strip.blank?
  end

  def cap_range_error(daily_cap)
    "El tope diario va de 1 a #{MAX_DAILY_CAP}." unless (1..MAX_DAILY_CAP).cover?(daily_cap.to_i)
  end
end
