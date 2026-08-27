# frozen_string_literal: true

# ================================================================================
# proyecto@botseller_webhook_saliente
# ================================================================================
# Job: BotSeller::OutgoingDispatchJob
# Descripción: Notifica a INTERNAL_WEBHOOK_URL (BotSeller::Dispatcher) también
#              para mensajes SALIENTES (respuestas de agente/bot), no solo
#              entrantes. Para entrantes, el dispatch ocurre dentro de
#              ContactTrackingResponseAnalyzerJob.
#
# Se dispara desde: Message.after_create_commit :dispatch_botseller_for_outgoing
# ================================================================================

class BotSeller::OutgoingDispatchJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.outgoing?
    return if message.private? || message.content.blank?
    return unless BotSeller::Dispatcher.configured?

    Rails.logger.info "[BotSeller] 📤 Notificando mensaje saliente ##{message_id}"
    BotSeller::Dispatcher.new(message).dispatch
  rescue StandardError => e
    Rails.logger.error "[BotSeller] ❌ Error notificando saliente: #{e.message}"
  end
end
