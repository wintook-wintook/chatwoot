# frozen_string_literal: true

# Probador de agentes — una prueba del lote: lo que escribe el cliente (uno o varios mensajes,
# en orden) y lo que se espera de la última respuesta.
class AgentTestCase < ApplicationRecord
  MAX_MESSAGES = 8
  ORIGINS = %w[correction manual].freeze # de un 👎 | guardada a mano desde el probador

  belongs_to :account
  belongs_to :batch, class_name: 'AgentTestBatch', foreign_key: :agent_test_batch_id, inverse_of: :cases

  validates :name, presence: true, length: { maximum: 120 }
  validates :origin, inclusion: { in: ORIGINS }
  validate :messages_present

  private

  def messages_present
    errors.add(:messages, 'necesita al menos un mensaje del cliente') if Array(messages).compact_blank.empty?
  end
end
