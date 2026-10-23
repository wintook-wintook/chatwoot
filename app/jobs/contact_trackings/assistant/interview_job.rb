# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — UN TURNO DE ENTREVISTA, EN SEGUNDO PLANO
# ================================================================================
# Editar un Entrenamiento largo es redactar, comprobar, corregir y probar el ruteo:
# varias llamadas a OpenAI que pasan con holgura los 15 s de rack-timeout. Dentro de
# la request eso era un 500 y la pantalla decía "No se pudo leer lo que tiene la
# cuenta" (cuenta 568, 30/09/2026). Igual que OptimizeJob: el controlador encola y
# responde 202, la pantalla consulta el resultado (TurnProgress.read_result) y el
# avance real sigue en TurnProgress.read.
#
# Cualquier falla también se guarda como resultado: sin eso la pantalla esperaría
# hasta agotar el tiempo sin saber qué pasó.
# ================================================================================

class ContactTrackings::Assistant::InterviewJob < ApplicationJob
  queue_as :default

  def perform(account_id, user_id, turn_id, args)
    account = Account.find(account_id)
    user = User.find(user_id)
    args = args.stringify_keys
    avance = ContactTrackings::Assistant::TurnProgress.new(account, user, turn_id)
    inbox = account.inboxes.find_by(id: args['inbox_id']) if args['inbox_id'].present?

    result = I18n.with_locale(args['locale'].presence || I18n.default_locale) do
      ContactTrackings::Assistant::InterviewTurn
        .new(account, user, args, inbox: inbox, progress: avance.method(:update)).call
    end
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, result)
  rescue StandardError => e
    Rails.logger.error "[Asistente] InterviewJob falló: #{e.class}: #{e.message}"
    ContactTrackings::Assistant::TurnProgress.store_result(account, user, turn_id, { error: 'unavailable' }) if account && user
  end
end
