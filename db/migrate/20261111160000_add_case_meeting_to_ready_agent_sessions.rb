# Agentes listos — la cita que el agente agendó en esa conversación (para moverla o cancelarla).
class AddCaseMeetingToReadyAgentSessions < ActiveRecord::Migration[7.0]
  def change
    add_reference :ready_agent_sessions, :case_meeting, foreign_key: { on_delete: :nullify }
  end
end
