# frozen_string_literal: true

# Tareas con el cliente y su portal.
#   case_tasks.audience: quién la hace — internal (como hoy), visible (nosotros, el cliente
#     ve el avance), client (la trabaja el cliente en su portal)
#   case_task_client_entries: lo que pasa en una tarea del cliente (empezó, comentó, subió
#     archivo, la completó; nosotros la regresamos o respondimos)
#   client_portal_links: el enlace del portal, por organización (o por contacto si no tiene)
class CreateClientTasksAndPortal < ActiveRecord::Migration[7.0]
  def change # rubocop:disable Metrics/MethodLength
    change_table :case_tasks, bulk: true do |t|
      t.integer :audience, null: false, default: 0
      t.boolean :requires_file, null: false, default: false
      t.string :client_status
      t.bigint :completed_by_contact_id
    end
    add_index :case_tasks, %i[case_ticket_id audience]

    create_table :case_task_client_entries do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :case_task, null: false, foreign_key: { on_delete: :cascade }
      t.references :case_ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.text :content
      t.timestamps
    end

    create_table :client_portal_links do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :organization, foreign_key: { on_delete: :cascade }
      t.references :contact, foreign_key: { on_delete: :cascade }
      t.string :token, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_used_at
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :client_portal_links, :token, unique: true
  end
end
