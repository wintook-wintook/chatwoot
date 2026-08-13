# frozen_string_literal: true

# @tickets_cases — Columnas del Kanban configurables por Tipo de Caso (Opción A+).
# Cada tipo define sus propias columnas (etiqueta, color, orden); cada columna cubre
# uno o más `status` del enum global. VARIAS columnas pueden cubrir el mismo estado:
# el ticket guarda en cuál está vía `case_tickets.case_type_column_id`.
class CreateCaseTypeColumns < ActiveRecord::Migration[7.0]
  def change
    create_table :case_type_columns do |t|
      t.bigint  :account_id,   null: false
      t.bigint  :case_type_id, null: false
      t.string  :label,    null: false
      t.string  :color,    null: false, default: '#64748b'
      t.integer :position, null: false, default: 0
      t.jsonb   :statuses, null: false, default: []
      t.timestamps
    end

    add_index :case_type_columns, %i[case_type_id position],
              name: 'index_case_type_columns_on_type_and_position'
    add_index :case_type_columns, :account_id
    add_foreign_key :case_type_columns, :accounts,   column: :account_id
    add_foreign_key :case_type_columns, :case_types, column: :case_type_id, on_delete: :cascade

    # Puntero del ticket a su sub-estado (columna). Nullable: NULL cae al fallback
    # por `status`. `on_delete: :nullify` → borrar una columna nunca borra tickets.
    add_column :case_tickets, :case_type_column_id, :bigint, null: true
    add_index  :case_tickets, :case_type_column_id
    add_foreign_key :case_tickets, :case_type_columns,
                    column: :case_type_column_id, on_delete: :nullify
  end
end
