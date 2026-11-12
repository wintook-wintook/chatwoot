# frozen_string_literal: true

# feat/ficha_agente_ia — corre la prueba de la ficha (Ficha::Tester) fuera del request:
# son ~20 llamadas en serie y pasan los 15 s de rack-timeout. El avance y el resultado
# van a Redis con TurnProgress (la pantalla los consulta con el turn_id).
#   params con template_id → un agente que ya existe (su Entrenamiento tal cual);
#   si no → lo capturado en la ficha de uno nuevo (Ficha::Draft).
class ContactTrackings::Ficha::TestJob < ApplicationJob
  queue_as :default

  def perform(account_id, user_id, turn_id, params)
    account = Account.find(account_id)
    user = User.find(user_id)
    avance = ContactTrackings::Assistant::TurnProgress.new(account, user, turn_id)
    salida = tester_for(account, params.to_h.stringify_keys)
             .call(progress: ->(hechas, total) { avance.update(:testing, done: hechas, total: total) })
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, salida)
  rescue StandardError => e
    Rails.logger.error "[Ficha] la prueba falló: #{e.class}: #{e.message}"
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, { error: e.message }) if account && user
  end

  private

  def tester_for(account, params)
    return existing_tester(account, params['template_id']) if params['template_id'].present?

    borrador = ContactTrackings::Ficha::Draft.new(account, params)
    ContactTrackings::Ficha::Tester.new(account, draft: borrador.result[:prompt], routes: borrador.result[:routes],
                                                 offers: borrador.active_offers, inbox: borrador.inbox)
  end

  def existing_tester(account, template_id)
    template = account.tracking_templates.find(template_id)
    cambios = ContactTrackings::Ficha::Changes.new(template)
    ContactTrackings::Ficha::Tester.new(account, draft: template.complementary_prompt, routes: cambios.test_routes,
                                                 offers: cambios.test_offers, inbox: template.inbox, from_description: true)
  end
end
