# Agentes listos: agentes empaquetados (el puesto es nuestro) que la empresa activa en una
# o varias bandejas. ready_agent_sessions: la plática de un agente en una conversación.
class CreateReadyAgents < ActiveRecord::Migration[7.0]
  def change
    create_agents
    create_sessions
  end

  private

  def create_agents
    create_table :ready_agents do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false # prospects (los demás puestos vienen después)
      t.string :name, null: false
      t.boolean :enabled, null: false, default: false
      t.bigint :inbox_ids, array: true, null: false, default: []
      t.jsonb :settings, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
  end

  def create_sessions
    create_table :ready_agent_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ready_agent, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.text :outcome
      t.jsonb :answers, null: false, default: {}
      t.jsonb :log, null: false, default: []
      t.text :last_error
      t.timestamps
    end
    add_index :ready_agent_sessions, :conversation_id, unique: true, where: "status IN ('active', 'paused')",
                                                       name: 'index_ready_agent_sessions_live_per_conversation'
  end
end
