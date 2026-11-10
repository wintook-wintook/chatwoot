# Asistente (Dali) — la conversación de cada usuario con el asistente de la
# plataforma. Los turnos y las propuestas de acción viven en `messages` (jsonb);
# una conversación nueva archiva la anterior (no se borra).
class CreateAssistantThreads < ActiveRecord::Migration[7.0]
  def change
    create_table :assistant_threads do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :messages, null: false, default: []
      t.boolean :archived, null: false, default: false
      t.timestamps
    end
    add_index :assistant_threads, [:account_id, :user_id, :archived]
  end
end
