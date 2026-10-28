# Plan-Trabajo-Campo R4 — equipos del cliente (con su historial de servicios) y
# mantenimientos recurrentes que generan las órdenes de trabajo solos.
class CreateCustomerAssetsAndMaintenancePlans < ActiveRecord::Migration[7.0]
  def change
    create_customer_assets
    create_maintenance_plans
    add_reference :case_tickets, :customer_asset, foreign_key: { on_delete: :nullify }
    add_reference :case_tickets, :maintenance_plan, foreign_key: { on_delete: :nullify }
  end

  private

  def create_customer_assets
    create_table :customer_assets do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :brand
      t.string :model
      t.string :serial
      t.string :location
      t.date :installed_on
      t.date :warranty_until
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_maintenance_plans
    create_table :maintenance_plans do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :customer_asset, foreign_key: { on_delete: :nullify }
      t.references :case_type, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.integer :every, null: false, default: 3
      t.integer :unit, null: false, default: 1
      t.date :next_due_on, null: false
      t.integer :lead_days, null: false, default: 7
      t.boolean :notify_customer, null: false, default: true
      t.boolean :active, null: false, default: true
      t.datetime :last_generated_at
      t.text :notes
      t.timestamps
    end
    add_index :maintenance_plans, %i[active next_due_on]
  end
end
