# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — PAUSAR UNA CAMPAÑA POR ERROR DE CONFIGURACIÓN
# ================================================================================
# Lo llama TrackingDeliveries::HandleFailure cuando Meta rechaza un envío por algo que
# haría fallar a todos (plantilla inexistente, cuenta bloqueada, pago, token...).
#
#   - La campaña queda Pausada con el motivo; deja de aceptar inscripciones
#     (TrackingCampaign#accepting_entries?).
#   - Sus seguimientos NO se pausan aquí uno por uno: ContactTrackingJob pausa cada uno
#     (paused_by_campaign) cuando le toca enviar. Así no se recorren las colas de Sidekiq
#     por cada seguimiento.
#   - Si ya estaba pausada, se conserva el primer motivo.
#
# Se reanuda con TrackingCampaigns::Resume.
#
# Pausa a mano (botón «Pausar campaña», PausesController): sin motivo. paused_reason vacío
# es lo que distingue en el detalle «la pausaste tú» de «la pausó un error de Meta».
# ================================================================================
class TrackingCampaigns::Pause
  PAUSABLE_STATUSES = %w[draft running].freeze

  def initialize(campaign, reason: nil)
    @campaign = campaign
    @reason = reason
  end

  def perform
    return false unless PAUSABLE_STATUSES.include?(@campaign.status)

    # update_columns: la pausa no puede depender de que la campaña pase sus validaciones.
    @campaign.update_columns(status: 'paused', paused_reason: @reason.to_s.truncate(250).presence, # rubocop:disable Rails/SkipsModelValidations
                             paused_at: Time.current, updated_at: Time.current)
    Rails.logger.warn "[TrackingCampaigns::Pause] campaña #{@campaign.id} pausada: #{@reason.presence || 'a mano'}"
    true
  end
end
