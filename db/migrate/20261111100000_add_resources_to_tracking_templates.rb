# feat/ficha_agente_ia F1 — la ficha del agente: qué recursos usa (docs/ficha_agente_ia_plan.md §4.2).
class AddResourcesToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    return if column_exists?(:tracking_templates, :resources)

    add_column :tracking_templates, :resources, :jsonb, null: false, default: {}
  end
end
