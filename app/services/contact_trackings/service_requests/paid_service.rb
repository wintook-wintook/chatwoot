# frozen_string_literal: true

# proyecto@solicitudes (pieza 5, F4) — pago recibido: los servicios quedan en firme (quita
# «[TENTATIVO]» de su tarea agendada) y se le avisa al cliente con sus números.
# Lo llaman la etiqueta «pago_confirmado» (todos) y la columna «Pagado» del Kanban (uno).
class ContactTrackings::ServiceRequests::PaidService
  def initialize(conversation)
    @conversation = conversation
  end

  def confirm!(casos)
    numeros = casos.map { |caso| ContactTrackings::ServiceRequests::Turn.number(caso, @conversation) }
    fallidos = casos.reject { |caso| confirm_case(caso) }
    say("✅ Recibimos tu pago. #{casos.one? ? 'Tu servicio' : 'Tus servicios'} #{numeros.join(', ')} " \
        "#{casos.one? ? 'quedó confirmado' : 'quedaron confirmados'}.", privado: false)
    return if fallidos.empty?

    say("⚠️ Pago marcado, pero no se pudo actualizar el calendario de: #{fallidos.map(&:title).join(', ')}. Confírmalo a mano.",
        privado: true)
  end

  private

  def confirm_case(caso)
    tarea = CaseMeeting.find_by(id: caso.metadata['meeting_id'])
    ok = tarea.present? && ContactTrackings::ServiceMeeting.new(tarea).confirm!
    caso.update!(metadata: caso.metadata.merge('estado' => 'confirmado')) if ok
    ok
  end

  def say(texto, privado:)
    mensaje = Messages::MessageBuilder.new(bot_user, @conversation, { content: texto, private: privado, message_type: 'outgoing' }).perform
    return if privado || mensaje.blank?

    mensaje.content_attributes[:sentiment_auto_reply] = true
    mensaje.save!
  end

  def bot_user
    account = @conversation.account
    account.users.first || AccountUser.where(account_id: account.id).first&.user || User.first
  end
end
