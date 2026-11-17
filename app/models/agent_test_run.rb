# frozen_string_literal: true

# Probador de agentes — una corrida de un lote contra un agente: cuántas pasaron y, por prueba,
# lo que contestó, si cumple y por qué (la bitácora de corridas).
class AgentTestRun < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  belongs_to :account
  belongs_to :batch, class_name: 'AgentTestBatch', foreign_key: :agent_test_batch_id, inverse_of: :runs
  belongs_to :tracking_template
  belongs_to :created_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
end
