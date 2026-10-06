# frozen_string_literal: true

# proyecto@automatizacion_campanas — las INSCRIPCIONES de una campaña
# (docs/automatizacion_campanas_plan.md §5.2).
#
# Un registro por cada intento de meter a un contacto en una campaña, entre o no:
#   enrolled  entró, y `contact_tracking_id` es el seguimiento que se le creó
#   skipped   no entró, y `reason` dice por qué (campaña cerrada, ya inscrito, Agente IA
#             activo en el inbox, fuera de la ventana, tope del día)
# Así la campaña sabe cuántos entraron por lote y por cada automatización, y cuántos no.
#
# Un contacto entra UNA vez por campaña (decisión 4): índice único parcial sobre los
# inscritos. Los omitidos se pueden repetir, y cuentan.
class CreateTrackingCampaignEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_campaign_entries do |t|
      # Chatwoot borra contactos, conversaciones, automatizaciones y seguimientos: la
      # inscripción no puede impedirlo. Sin contacto no hay inscripción; lo demás queda en nil.
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :tracking_campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :automation_rule, foreign_key: { on_delete: :nullify }
      t.references :contact_tracking, foreign_key: { on_delete: :nullify }
      t.string :source, null: false
      t.string :status, null: false
      t.string :reason
      t.timestamps
    end

    add_index :tracking_campaign_entries, %i[tracking_campaign_id contact_id], unique: true,
                                                                               where: "status = 'enrolled'",
                                                                               name: 'index_tracking_campaign_entries_one_enrollment'
    add_index :tracking_campaign_entries, %i[tracking_campaign_id status], name: 'index_tracking_campaign_entries_by_status'
  end
end
