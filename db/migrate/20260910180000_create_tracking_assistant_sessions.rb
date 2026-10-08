# proyecto@asistente_agentes_ia — la conversación del Asistente, persistida.
#
# Hasta ahora el hilo vivía solo en el navegador: cerrar la pestaña perdía la
# entrevista entera. Una entrevista dura 30–45 minutos, así que eso no es un
# detalle: es tirar el trabajo de media sesión.
#
# SE LLAMA tracking_assistant_sessions Y NO assistant_sessions a propósito. En
# esta base ya existe `ai_agent_assistant_sessions`, huérfana del PR #23 que se
# mergeó y se revirtió, y Chatwoot tiene además su propio asistente (Captain).
# Un nombre genérico dejaría tres cosas parecidas sin manera de distinguirlas.
# El prefijo la ata al módulo de Seguimientos, igual que su controlador.
class CreateTrackingAssistantSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_assistant_sessions do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # Si terminó guardando, a qué Agente IA. Nullable: la mayoría no llega ahí.
      t.references :tracking_template, foreign_key: { on_delete: :nullify }

      # open = se puede retomar · saved = terminó en un agente · discarded = se cerró
      t.string :status, null: false, default: 'open'
      # Los turnos de la entrevista. jsonb y no una tabla aparte porque siempre se
      # leen enteros: nunca hace falta un mensaje suelto.
      t.jsonb :messages, null: false, default: []
      t.text :draft
      t.jsonb :validation, null: false, default: {}
      t.jsonb :proposal, null: false, default: {}

      t.timestamps
    end

    # La consulta que importa: "¿tengo una conversación a medias?" al abrir la
    # pantalla, y el listado por persona.
    add_index :tracking_assistant_sessions, %i[account_id user_id status updated_at],
              name: 'idx_tracking_assistant_sessions_lookup'
  end
end
