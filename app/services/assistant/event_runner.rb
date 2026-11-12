# frozen_string_literal: true

# Asistente (Dali) — crea (o reutiliza) el enlace NFC confirmado. El resultado lleva `url`
# para que la tarjeta ofrezca «Grabar en etiqueta» (Web NFC) o «Copiar enlace».
# Se incluye en Assistant::Executor.
module Assistant::EventRunner
  def run_nfc_link(payload)
    raise Assistant::Executor::Refused, 'No tienes permiso para crear enlaces en Campañas.' unless @grant.writable?(:campaigns)

    event = @account.events.find(payload['event_id'])
    inbox = @tools.nfc_inbox(payload['inbox_id'])
    link = event.capture_links.find_by(inbox: inbox, user_id: payload['user_id'].presence) ||
           event.capture_links.create!(account: @account, inbox: inbox, user_id: payload['user_id'].presence,
                                       message: payload['message'].to_s)
    done("Enlace NFC listo · #{event.name}", "#{base}/events/#{event.id}").merge('url' => link.url)
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end
end
