# feat/licencias (F0) — LICENCIAS POR CUENTA (historial)
# Plan: docs/licencias_plan_v1.md §4–§5. Una cuenta sin filas aquí está FUERA DE LICENCIA y se
# comporta como hoy. Con filas: a lo sumo UNA activa (índice único parcial) y N programadas en
# cola. name / max_agents / duration_days son la copia del plan al emitir.
class CreateAccountLicenses < ActiveRecord::Migration[7.0]
  def change
    create_table :account_licenses do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :license_plan, foreign_key: { on_delete: :nullify }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.integer :license_type, null: false, default: 1 # demo: 0, paid: 1
      t.integer :status, null: false, default: 0 # active: 0, scheduled: 1, expired: 2, cancelled: 3
      t.integer :max_agents, null: false
      t.integer :duration_days, null: false
      t.datetime :starts_at
      t.datetime :expires_at
      t.jsonb :reminded_at, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.text :notes
      t.timestamps
    end
    add_license_indexes
  end

  private

  def add_license_indexes
    add_index :account_licenses, [:account_id, :status]
    add_index :account_licenses, :account_id, unique: true, where: 'status = 0',
                                              name: 'index_account_licenses_one_active_per_account'
    add_index :account_licenses, [:status, :expires_at]
  end
end
