# proyecto@arreglar_predefinidas — «Arreglar con IA» una predefinida que pasa del tope de
# caracteres: la propuesta (limpieza, partes o versión condensada), sus candados y si se
# aplicó. `source_digest` es la huella del texto original al proponer: si alguien la
# edita después, la propuesta ya no aplica.
class CreateCannedResponseFixes < ActiveRecord::Migration[7.0]
  def change
    create_table :canned_response_fixes do |t|
      t.references :account, null: false, foreign_key: true, type: :integer
      t.references :canned_response, type: :integer, foreign_key: { on_delete: :nullify }
      t.references :user, type: :integer, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: 'running'
      t.string :source_digest, null: false
      t.jsonb :proposal, null: false, default: {}
      t.jsonb :checks, null: false, default: {}
      t.string :error
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end
  end
end
