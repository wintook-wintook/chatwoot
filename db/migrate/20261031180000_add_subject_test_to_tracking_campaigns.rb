# prospeccion P3 (docs/prospeccion_estudio.md §10.10) — prueba A/B de asuntos.
#   Campaña:     el asunto B (el A es email_subject) y el ganador elegido ('a' / 'b').
#   Seguimiento: qué asunto recibió ('a' / 'b'); nil si no participó (ya tenía hilo,
#                no es correo, o la prueba ya tenía ganador).
class AddSubjectTestToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    change_table :tracking_campaigns, bulk: true do |t|
      t.string :email_subject_b
      t.string :subject_ab_winner
    end
    add_column :contact_trackings, :subject_variant, :string
    add_index :contact_trackings, [:tracking_campaign_id, :subject_variant], where: 'subject_variant IS NOT NULL',
                                                                             name: 'index_contact_trackings_on_campaign_and_subject_variant'
  end
end
