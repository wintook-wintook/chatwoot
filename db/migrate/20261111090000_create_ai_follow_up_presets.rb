# frozen_string_literal: true

# Plantillas de seguimiento: la «receta» de un Seguimiento IA (objetivo, instrucciones, ritmo,
# qué hacer al terminar y plantilla de WhatsApp preferida) para volver a usarla al delegar.
class CreateAiFollowUpPresets < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_follow_up_presets do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.text :objective, null: false
      t.text :instructions
      t.integer :max_attempts, null: false, default: 3
      t.integer :interval_value, null: false, default: 1
      t.string :interval_unit, null: false, default: 'days'
      t.string :on_finish, null: false, default: 'notify'
      t.string :template_name
      t.string :template_language
      t.timestamps
    end
    add_index :ai_follow_up_presets, 'account_id, lower(name)', unique: true, name: 'index_ai_follow_up_presets_on_account_and_name'
  end
end
