# prospeccion V0 — para qué es la campaña: seguimiento (contactos que ya conoces) o
# prospección (clientes nuevos, hasta que muestren interés). Las campañas existentes son
# de seguimiento.
class AddPurposeToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_campaigns, :purpose, :string, null: false, default: 'follow_up'
    add_index :tracking_campaigns, %i[account_id purpose]
  end
end
