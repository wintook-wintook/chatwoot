# frozen_string_literal: true

# Motor 2.0 — el caso abierto de la conversación (o el vigente del contacto) registra que el
# cliente escribió y corre sus reglas. Copia del gancho del 1.0
# (ContactTrackingResponseAnalyzerJob#process_message_for_tracking), que no se toca.
module Motor2::TicketHook
  module_function

  def call(message)
    ticket = message.conversation.case_tickets.where.not(status: %w[closed cancelled]).order(created_at: :desc).first ||
             Cases::OrchestratorService.new(account: message.account, contact: message.conversation.contact,
                                            conversation: message.conversation).find_active_ticket
    return unless ticket

    ticket.update_columns(first_response_at: Time.current) if ticket.first_response_at.nil? # rubocop:disable Rails/SkipsModelValidations
    ticket.case_events.create!(account: message.account, event_type: :message_received, origin: :bot,
                               payload: { message_id: message.id })
    Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
  rescue StandardError => e
    Rails.logger.error("[Motor2] caso: #{e.message}")
  end
end
