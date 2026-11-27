# frozen_string_literal: true

# Probador de agentes — quien prueba solo dice qué debió responder; quien entrena revisa aparte.
#   agent_test_logs.note              «¿Qué estuvo mal?» (opcional) de quien probó; `feedback` es «¿Qué
#                                     debió responder?». El diagnóstico lo ve solo quien revisa.
#   agent_test_logs.dismissed_reason  por qué quien revisa dijo «No es error».
class AgentTesterRevision < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_test_logs, :note, :text
    add_column :agent_test_logs, :dismissed_reason, :text
  end
end
