# Plan-Trabajo-Campo R1 — reporte de servicio de la orden de trabajo: «en campo»
# por tipo y por orden, bitácora (notas, fotos, archivos), horas, enlace del
# reporte para el cliente y materiales tomados del catálogo.
class CreateServiceReport < ActiveRecord::Migration[7.0]
  def change
    add_column :case_types, :field_settings, :jsonb, null: false, default: {}
    add_column :case_tickets, :on_site, :boolean
    add_column :case_tickets, :report_token, :string
    add_column :case_tickets, :report_sent_at, :datetime
    add_index :case_tickets, :report_token, unique: true
    add_reference :case_work_order_items, :catalog_item, foreign_key: { on_delete: :nullify }

    create_table :case_work_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.integer :kind, null: false, default: 0
      t.integer :tag
      t.text :content
      t.timestamps
    end

    create_table :case_time_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :case_ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :minutes
      t.integer :source, null: false, default: 0
      t.string :note
      t.timestamps
    end
  end
end
