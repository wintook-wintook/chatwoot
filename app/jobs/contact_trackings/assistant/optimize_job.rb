# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — OPTIMIZAR UN ENTRENAMIENTO, EN SEGUNDO PLANO
# ================================================================================
# La llamada a OpenAI con un Entrenamiento largo tarda 40–60 s y rack-timeout corta
# las requests a los 15 s (500 en producción, 21/09/2026). Por eso corre acá y no en
# la request: el controlador encola y responde 202, y la pantalla consulta el
# resultado (TurnProgress.read_result) mientras el avance real sigue en
# TurnProgress.read.
#
# Cualquier falla también se guarda como resultado: sin eso la pantalla esperaría
# hasta agotar el tiempo sin saber qué pasó.
# ================================================================================

class ContactTrackings::Assistant::OptimizeJob < ApplicationJob
  queue_as :default

  def perform(account_id, user_id, turn_id, draft, inbox_id = nil)
    account = Account.find(account_id)
    user = User.find(user_id)
    avance = ContactTrackings::Assistant::TurnProgress.new(account, user, turn_id)
    inbox = account.inboxes.find_by(id: inbox_id) if inbox_id

    result = ContactTrackings::Assistant::Optimizer
             .new(account, draft: draft, inbox: inbox, progress: avance.method(:update)).call
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, result)
  rescue StandardError => e
    Rails.logger.error "[Asistente] OptimizeJob falló: #{e.class}: #{e.message}"
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, { error: 'unavailable' }) if account && user
  end
end
