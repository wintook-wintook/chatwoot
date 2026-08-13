# frozen_string_literal: true

# proyecto@ai_agent_assistant — F5: el chat asistente.
#
# Una sesión = una conversación con su borrador. `tracking_template_id` es
# nullable a propósito: la entrevista puede empezar ANTES de que exista el agente.
#
# `draft` guarda el borrador estructurado y `proposals` lo que el asistente
# propuso en el último turno pero el usuario todavía no aceptó. Están separados
# porque la regla del módulo es aplicar POR CAMPO, nunca en bloque: mientras una
# propuesta no se aplica, no toca el borrador.
class CreateAiAgentAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_agent_assistant_sessions do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id,    null: false
      t.bigint :tracking_template_id
      t.string :mode, null: false, default: 'interview'
      t.string :step
      t.jsonb  :messages,  null: false, default: []
      t.jsonb  :draft,     null: false, default: {}
      t.jsonb  :proposals, null: false, default: []
      t.timestamps
    end

    add_index :ai_agent_assistant_sessions, %i[account_id user_id]
    add_index :ai_agent_assistant_sessions, :tracking_template_id

    add_foreign_key :ai_agent_assistant_sessions, :accounts, column: :account_id
    add_foreign_key :ai_agent_assistant_sessions, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :ai_agent_assistant_sessions, :tracking_templates,
                    column: :tracking_template_id, on_delete: :nullify
  end
end
