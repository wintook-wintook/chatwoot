# proyecto@ai_agent_attachments
# Adjuntos de un Agente IA (tracking_template). El binario vive en ActiveStorage;
# `name` es la clave (slug) que referencia la directiva @adjunto:name del prompt complementario.
class CreateAiAgentAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_agent_attachments do |t|
      t.references :tracking_template, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :ai_agent_attachments, [:tracking_template_id, :name], unique: true,
              name: 'index_ai_agent_attachments_on_template_and_name'
  end
end
