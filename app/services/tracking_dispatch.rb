# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: despachador de seguimientos
# ================================================================================
# En las cuentas con despachador (TrackingDispatch::Settings) ya no hay un job programado
# por seguimiento: cada minuto TrackingDispatch::DispatchJob toma los vencidos
# (TrackingDispatch::Claim) y encola TrackingDispatch::SendJob por cada uno.
# ================================================================================
module TrackingDispatch
  # dispatched_at en texto, con microsegundos: viaja en el job y se compara con la columna.
  def self.token(time)
    time&.utc&.iso8601(6)
  end

  def self.enabled_for?(account_id)
    TrackingDispatch::Settings.enabled_for?(account_id)
  end
end
