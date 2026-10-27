# prospeccion V5 — en qué va cada prospecto de una campaña de Prospección (§8.1).
#   prospect_stage: replied · interested · handed_off (nunca baja de nivel)
#   prospect_exit:  not_now · not_interested · wrong_person · opted_out
# «Contactado» y «sin respuesta» no se guardan: salen de attempt_count y del estado.
class AddProspectStageToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :prospect_stage, :string
    add_column :contact_trackings, :prospect_exit, :string
    add_column :contact_trackings, :prospect_classified_at, :datetime
    add_index :contact_trackings, %i[tracking_campaign_id prospect_stage], name: :index_contact_trackings_on_campaign_and_prospect_stage
  end
end
