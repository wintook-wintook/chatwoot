# frozen_string_literal: true

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Migración: CreateCommandSessions
# Descripción: Crea la tabla command_sessions para manejar el flujo conversacional
#              de comandos enviados por agentes vía WhatsApp/Website
# Fecha: 2026-02-18
# ================================================================================

class CreateCommandSessions < ActiveRecord::Migration[7.0]
  def up
    create_table :command_sessions do |t|
      # Referencias
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true

      # Campos del comando
      t.string :command, null: false
      t.string :current_step, null: false
      t.jsonb :collected_data, default: {}

      # Estado y errores
      t.string :status, null: false, default: 'active'
      t.text :last_error

      # Expiración automática
      t.datetime :expires_at, null: false

      t.timestamps
    end

    # Índice para buscar sesiones activas por conversación
    add_index :command_sessions, [:conversation_id, :status],
              name: 'index_command_sessions_on_conversation_and_status'

    # Índice para el job de expiración
    add_index :command_sessions, [:status, :expires_at],
              name: 'index_command_sessions_on_status_and_expires_at'

    # Índice único: solo una sesión activa por conversación
    add_index :command_sessions, [:conversation_id],
              unique: true,
              where: "status = 'active'",
              name: 'index_unique_active_session_per_conversation'
  end

  def down
    drop_table :command_sessions
  end
end
