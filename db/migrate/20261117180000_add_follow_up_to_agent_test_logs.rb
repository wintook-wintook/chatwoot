# frozen_string_literal: true

# Probador de agentes — cada 👎 de la bitácora se sigue hasta que queda: pendiente → corregido y
# probado de nuevo (quedó / sigue fallando), con la prueba que se guardó de él.
class AddFollowUpToAgentTestLogs < ActiveRecord::Migration[7.0]
  def change
    change_table :agent_test_logs, bulk: true do |t|
      t.string :status, default: 'pending', null: false # pending | retesting | passed | failing
      t.bigint :agent_test_case_id
      t.jsonb :retest, default: {}, null: false # { run_id, reply, reason, at }
    end
  end
end
