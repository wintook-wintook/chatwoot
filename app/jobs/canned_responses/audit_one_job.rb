# frozen_string_literal: true

# proyecto@auditoria_predefinidas — revisar UNA predefinida contra sus vecinas en cuanto
# tiene su vector nuevo (lo encola KnowledgeItemSyncJob al guardarla desde el formulario).
# Sin integración de OpenAI no hace nada: el tamaño se sigue viendo, que es en vivo.
class CannedResponses::AuditOneJob < ApplicationJob
  queue_as :low

  def perform(canned_response_id)
    response = CannedResponse.find_by(id: canned_response_id)
    return unless response

    CannedResponses::Audit::Runner.new(response.account).one(response)
  rescue CannedResponses::Audit::Runner::NoKeyError
    nil
  end
end
