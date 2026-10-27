# prospeccion F1 — asunto propio de la campaña cuando el Agente IA escribe por correo.
# Sin él, la conversación que abre el agente no tiene mail_subject y el correo sale con
# «[#N] Nuevos mensajes en esta conversación».
class AddEmailSubjectToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_campaigns, :email_subject, :string
  end
end
