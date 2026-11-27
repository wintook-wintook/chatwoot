# Ajustes › Demostraciones — cada importación de un kit de demo (agentes, catálogo, bandejas) recuerda lo que creó,
# para «Limpiar lo de la demo» (pláticas, cotizaciones, citas que salieron en la demo) y «Quitar la demo» (todo).
class CreateDemoImports < ActiveRecord::Migration[7.0]
  def change
    create_table :demo_imports do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :source
      t.jsonb :created_ids, null: false, default: {}
      t.timestamps
    end
  end
end
