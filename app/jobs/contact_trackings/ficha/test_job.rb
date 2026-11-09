# frozen_string_literal: true

# feat/ficha_agente_ia — corre la prueba de la ficha (Ficha::Tester) fuera del request:
# son ~20 llamadas en serie y pasan los 15 s de rack-timeout. El avance y el resultado
# van a Redis con TurnProgress (la pantalla los consulta con el turn_id).
class ContactTrackings::Ficha::TestJob < ApplicationJob
  queue_as :default

  def perform(account_id, user_id, turn_id, params)
    account = Account.find(account_id)
    user = User.find(user_id)
    avance = ContactTrackings::Assistant::TurnProgress.new(account, user, turn_id)
    borrador = ContactTrackings::Ficha::Draft.new(account, params)
    resultado = borrador.result
    salida = ContactTrackings::Ficha::Tester.new(account, draft: resultado[:prompt], routes: resultado[:routes],
                                                          offers: borrador.active_offers, inbox: borrador.inbox)
                                            .call(progress: ->(hechas, total) { avance.update(:testing, done: hechas, total: total) })
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, salida)
  rescue StandardError => e
    Rails.logger.error "[Ficha] la prueba falló: #{e.class}: #{e.message}"
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, { error: e.message }) if account && user
  end
end
