# @tickets_cases 3A — Configuración de IA por cuenta (modo por acción).
class CreateCaseAiConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :case_ai_configs do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.jsonb   :modes,   null: false, default: {}
      t.string  :model_override

      t.timestamps
    end
  end
end
