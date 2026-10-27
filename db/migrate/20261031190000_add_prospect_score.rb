# prospeccion P4 (docs/prospeccion_estudio.md §10.11) — puntuación 0–100 del prospecto.
#   Campaña:     scoring = { weights: {...}, rules: {...} } (vacío = valores sugeridos de §8.2).
#   Seguimiento: la puntuación, su desglose y cuándo se calculó; y lo que la IA leyó en sus
#                respuestas (P4.2): motivos del interés (price · info · meeting) y si decide.
class AddProspectScore < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_campaigns, :scoring, :jsonb, default: {}, null: false

    change_table :contact_trackings, bulk: true do |t|
      t.integer :prospect_score
      t.jsonb :prospect_score_parts, default: {}, null: false
      t.datetime :prospect_scored_at
      t.jsonb :prospect_signals, default: [], null: false
      t.string :prospect_decision_maker
    end
    add_index :contact_trackings, [:tracking_campaign_id, :prospect_score], name: 'index_contact_trackings_on_campaign_and_score'
  end
end
