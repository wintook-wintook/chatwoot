# prospeccion §10.12 (U1, D20, D25) — una sola campaña: la IA clasifica las respuestas en TODAS
# las campañas; lo que hace con eso es opción de la campaña (prendidas por omisión):
#   stop_when_not_interested → «no le interesa» detiene los toques
#   stop_when_wrong_person   → «no es la persona» detiene los toques (número o correo equivocado)
#   retry_not_now            → «ahora no» deja un solo toque más a los 30 días
# Las campañas que eran de seguimiento (follow_up) quedan con las tres apagadas: así siguen
# funcionando exactamente como antes.
class AddReplyOptionsToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def up
    change_table :tracking_campaigns, bulk: true do |t|
      t.boolean :stop_when_not_interested, default: true, null: false
      t.boolean :stop_when_wrong_person, default: true, null: false
      t.boolean :retry_not_now, default: true, null: false
    end
    execute <<~SQL.squish
      UPDATE tracking_campaigns
         SET stop_when_not_interested = FALSE, stop_when_wrong_person = FALSE, retry_not_now = FALSE
       WHERE purpose = 'follow_up'
    SQL
  end

  def down
    change_table :tracking_campaigns, bulk: true do |t|
      t.remove :stop_when_not_interested, :stop_when_wrong_person, :retry_not_now
    end
  end
end
