# frozen_string_literal: true

# proyecto@hoja_buscar, pieza 4 — la etiqueta «pago_confirmado» deja en firme el servicio
# apartado de la conversación y se lo avisa al cliente (ver ServiceConfirmationListener).
class ContactTrackings::PaymentConfirmedJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.nil?

    ContactTracking.where(conversation_id: conversation.id).where(appointment_status: 'pending_payment').find_each do |tracking|
      confirm(tracking, conversation)
    end
  end

  private

  def confirm(tracking, conversation)
    confirmacion = ContactTrackings::ServiceConfirmation.new(tracking)
    return unless confirmacion.open?

    zona = tracking.tracking_template&.timezone.presence || 'America/Mexico_City'
    cuando = confirmacion.when_text(zona)
    if confirmacion.confirm!
      say(tracking, conversation, "✅ Recibimos tu pago. Tu servicio del #{cuando} quedó confirmado.", privado: false)
      say(tracking, conversation, "✅ Pago confirmado: el servicio del #{cuando} quedó en firme en el calendario.", privado: true)
    else
      say(tracking, conversation, "⚠️ Se marcó el pago pero no se pudo actualizar el calendario del servicio del #{cuando}. " \
                                  'Confírmalo a mano.', privado: true)
    end
  end

  def say(tracking, conversation, texto, privado:)
    mensaje = Messages::MessageBuilder.new(bot_user(tracking.account), conversation,
                                           { content: texto, private: privado, message_type: 'outgoing' }).perform
    return if privado || mensaje.blank?

    mensaje.content_attributes[:sentiment_auto_reply] = true
    mensaje.save!
  end

  # El mismo usuario con el que contesta el bot (ContactTrackingResponseAnalyzerJob#bot_user).
  def bot_user(account)
    account.users.first || AccountUser.where(account_id: account.id).first&.user || User.first
  end
end
