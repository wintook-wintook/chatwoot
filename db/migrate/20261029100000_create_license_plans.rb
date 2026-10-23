# feat/licencias (F0) — CATÁLOGO DE PLANES
# Plan: docs/licencias_plan_v1.md §4. Un plan es un molde: al emitir una licencia se COPIAN sus
# valores (snapshot), así que editar o desactivar un plan no altera lo ya emitido.
# El plan con signup_default = true es la demo que recibe toda cuenta nueva (F1); solo puede
# haber uno. Se crea aquí la demo de arranque (15 días / 2 agentes), editable después.
class CreateLicensePlans < ActiveRecord::Migration[7.0]
  def up
    create_table :license_plans do |t|
      t.string :name, null: false
      t.integer :duration_days, null: false
      t.integer :default_max_agents, null: false
      t.integer :license_type, null: false, default: 1 # demo: 0, paid: 1
      t.jsonb :features, null: false, default: []
      t.boolean :signup_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :license_plans, :signup_default, unique: true, where: 'signup_default',
                                               name: 'index_license_plans_one_signup_default'

    execute <<~SQL.squish
      INSERT INTO license_plans (name, duration_days, default_max_agents, license_type, signup_default, position, created_at, updated_at)
      VALUES ('Demo', 15, 2, 0, TRUE, 0, NOW(), NOW())
    SQL
  end

  def down
    drop_table :license_plans
  end
end
