# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Job: ContactTrackings::KeywordCheckerJob
# Descripción: Evalúa palabras clave de acción en mensajes SALIENTES.
#              Para entrantes, la evaluación ocurre en ContactTrackingResponseAnalyzerJob.
#
# Se dispara desde: Message.after_create_commit :check_keyword_actions_for_outgoing
# Acción: silenciosa — sin respuesta al contacto
# ================================================================================

module ContactTrackings
  class KeywordCheckerJob < ApplicationJob
    queue_as :default

    def perform(message_id)
      message = Message.find_by(id: message_id)
      return if message.nil? || message.content.blank?
      return if message.incoming?

      Rails.logger.info "[KeywordChecker] 📤 Evaluando saliente ##{message_id}"

      trackings = find_active_trackings(message)
      return if trackings.empty?

      trackings.each do |tracking|
        service = ContactTrackings::KeywordActionService.new(tracking, message.content, 'outgoing')
        if service.call
          Rails.logger.info "[KeywordChecker] ✅ Acción ejecutada en tracking ##{tracking.id}"
        end
      end
    rescue StandardError => e
      Rails.logger.error "[KeywordChecker] ❌ Error: #{e.message}"
    end

    private

    def find_active_trackings(message)
      return [] unless message.conversation_id

      ContactTracking
        .where(conversation_id: message.conversation_id)
        .where(status: %w[active scheduled pending paused])
    end
  end
end
