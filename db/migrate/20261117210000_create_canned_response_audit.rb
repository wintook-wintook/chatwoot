# proyecto@auditoria_predefinidas — revisar el contenido de las respuestas predefinidas:
#   canned_response_audits    cada corrida de «Auditar» (estado, cuándo, cuánto revisó);
#   canned_response_findings  lo que encontró: duplicadas, que se solapan, que se
#                             contradicen o mal redactadas. Una o dos predefinidas por
#                             hallazgo; `digest` es la huella del texto de cada una al
#                             momento de encontrarlo, para que un «Descartar» valga
#                             mientras el texto no cambie.
class CreateCannedResponseAudit < ActiveRecord::Migration[7.0]
  def change
    create_table :canned_response_audits do |t|
      t.references :account, null: false, foreign_key: true, type: :integer
      t.string :status, null: false, default: 'running'
      t.jsonb :stats, null: false, default: {}
      t.string :error
      t.datetime :finished_at
      t.timestamps
    end

    create_table :canned_response_findings do |t|
      t.references :account, null: false, foreign_key: true, type: :integer
      t.references :canned_response, null: false, type: :integer,
                                     foreign_key: { on_delete: :cascade }
      t.references :other_canned_response, type: :integer,
                                           foreign_key: { to_table: :canned_responses, on_delete: :cascade }
      t.string :kind, null: false
      t.string :severity, null: false, default: 'medium'
      t.string :status, null: false, default: 'open'
      t.float :similarity
      t.jsonb :details, null: false, default: {}
      t.string :digest, null: false
      t.timestamps
    end
    add_index :canned_response_findings, [:account_id, :status]
  end
end
