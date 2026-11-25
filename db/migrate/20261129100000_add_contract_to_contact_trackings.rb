# Campaña con IA · Recordar — cada envío ligado a su contrato: qué le vence, la fecha y el monto exactos (aunque el
# contacto tenga varios contratos). TrackingCampaigns::RenewEnroll lo llena al inscribirlo.
class AddContractToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_reference :contact_trackings, :contract, foreign_key: { on_delete: :nullify }
  end
end
