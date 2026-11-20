# frozen_string_literal: true

# Campañas Motor 2.0 (pantalla nueva, aparte de la 1.0): la campaña trae su oferta (brief) y sus toques
# por canal; el «Vendedor de campaña» (agente 2.0) la atiende. Las de antes quedan en engine '1'.
# tracking_campaign_clicks: cada clic en una liga de un correo de campaña (TrackingCampaigns::ClickLink).
class CampaignsMotor2 < ActiveRecord::Migration[7.0]
  def change
    change_table :tracking_campaigns, bulk: true do |t|
      t.string :engine, null: false, default: '1'
      t.jsonb :brief, null: false, default: {}
      t.jsonb :touches, null: false, default: {}
    end

    create_table :tracking_campaign_clicks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_campaign, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :contact_tracking_id, null: false
      t.bigint :contact_id, null: false
      t.string :url, null: false, limit: 2000
      t.datetime :created_at, null: false
    end
    add_index :tracking_campaign_clicks, %i[tracking_campaign_id contact_id], name: 'index_campaign_clicks_on_campaign_and_contact'
  end
end
