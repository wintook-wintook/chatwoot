# frozen_string_literal: true

# Probador de agentes — un lote de pruebas (p. ej. «Becas», «Quejas»): se corre completo contra
# un agente 1.0 o 2.0.
class AgentTestBatch < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :cases, class_name: 'AgentTestCase', dependent: :destroy
  has_many :runs, class_name: 'AgentTestRun', dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
end
