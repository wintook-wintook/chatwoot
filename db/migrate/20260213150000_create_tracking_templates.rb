# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Migración: Crear tabla tracking_templates
# Campos: account_id, name, objective, ai_context, complementary_prompt,
#          whatsapp_templates (JSON), tags (JSON)
# ================================================================================

class CreateTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_templates do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :objective, null: false
      t.text :ai_context
      t.text :complementary_prompt
      t.json :whatsapp_templates, default: []
      t.json :tags, default: []

      t.timestamps
    end

    add_index :tracking_templates, [:account_id, :name], unique: true, name: 'index_tracking_templates_on_account_id_and_name'
  end
end
