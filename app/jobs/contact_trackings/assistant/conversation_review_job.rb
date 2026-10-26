# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REVISAR UNA CONVERSACIÓN, EN SEGUNDO PLANO
# ================================================================================
# Re-correr cada mensaje del cliente por el motor y el veredicto de gpt-4o tardan más
# que los 15 s de rack-timeout. Igual que OptimizeJob: el controlador encola y
# responde 202, y la pantalla consulta el resultado (TurnProgress.read_result).
#
# El idioma viaja con el job: en Sidekiq no hay request que lo ponga, y el veredicto
# se escribe en el de la cuenta.
# ================================================================================

class ContactTrackings::Assistant::ConversationReviewJob < ApplicationJob
  queue_as :default

  def perform(account_id, user_id, turn_id, args)
    account = Account.find(account_id)
    user = User.find(user_id)
    args = args.symbolize_keys
    avance = ContactTrackings::Assistant::TurnProgress.new(account, user, turn_id)
    inbox = account.inboxes.find_by(id: args[:inbox_id]) if args[:inbox_id]

    result = I18n.with_locale(args[:locale].presence || I18n.default_locale) do
      ContactTrackings::Assistant::ConversationReview
        .new(account, display_id: args[:display_id], note: args[:note], draft: args[:draft],
                      inbox: inbox, progress: avance.method(:update)).call
    end
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, result)
  rescue StandardError => e
    Rails.logger.error "[Asistente] ConversationReviewJob falló: #{e.class}: #{e.message}"
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, { error: 'unavailable' }) if account && user
  end
end
