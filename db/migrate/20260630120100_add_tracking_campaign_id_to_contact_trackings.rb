# @campanas_vendedor
# ================================================================================
# Migración: Agregar tracking_campaign_id a contact_trackings
# ================================================================================
# FK que vincula cada seguimiento con la campaña (corrida masiva) que lo creó.
# Nullable: los seguimientos asignados individualmente no pertenecen a una campaña.
# ================================================================================

class AddTrackingCampaignIdToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_reference :contact_trackings, :tracking_campaign, null: true, foreign_key: true, index: true
  end
end
