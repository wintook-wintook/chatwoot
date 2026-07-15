# @campanas_vendedor
# ================================================================================
# Migración: Crear tabla tracking_campaigns
# ================================================================================
# Agrupador con nombre para una asignación masiva de seguimientos (Agente IA).
# Cada corrida del bulk assign crea una TrackingCampaign; sus contact_trackings
# se cuelgan vía tracking_campaign_id y de ahí salen las estadísticas del dashboard.
# NO confundir con el Campaign nativo de Chatwoot (envíos one_off/ongoing).
# ================================================================================

class CreateTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_campaigns do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.references :tracking_template, null: true, foreign_key: true, index: true
      t.references :inbox, null: true, foreign_key: true, index: true
      t.references :user, null: true, foreign_key: true, index: true
      t.string :objective
      t.datetime :scheduled_for
      t.string :status, null: false, default: 'running'

      t.timestamps
    end

    add_index :tracking_campaigns, [:account_id, :status]
  end
end
