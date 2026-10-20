# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a: datos de la orden en columnas
# reales de case_tickets (solo los usa la clase Orden de trabajo) y su lista de
# materiales. La conformidad (quién recibió, cuándo, nota) se llena al cerrar.
class AddWorkOrderToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    change_table :case_tickets, bulk: true do |t|
      t.string   :work_address
      t.decimal  :estimated_hours, precision: 6, scale: 2
      t.decimal  :actual_hours, precision: 6, scale: 2
      t.boolean  :billable, null: false, default: false
      t.string   :received_by
      t.datetime :received_at
      t.text     :conformity_note
    end

    create_table :case_work_order_items do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :case_ticket, null: false, foreign_key: { on_delete: :cascade }
      t.string  :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1
      t.string  :unit
      t.decimal :unit_cost, precision: 14, scale: 2
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
