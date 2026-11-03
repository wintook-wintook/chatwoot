# Plan Actividad del caso — un caso puede ligar más conversaciones del contacto
# (p. ej. el hilo de correo) además de la principal (case_tickets.conversation_id).
# La principal no se guarda aquí: sigue siendo la que responde y reabre el caso.
class CreateCaseTicketConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :case_ticket_conversations do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :case_ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :linked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :case_ticket_conversations, [:case_ticket_id, :conversation_id], unique: true,
                                                                               name: 'idx_case_ticket_conversations_unique'
  end
end
