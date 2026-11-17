# frozen_string_literal: true

# Asistente (Dali) — la llamada confirmada. El servidor no llama (el audio sale del navegador):
# revisa otra vez que se pueda y devuelve en `call` lo que el dashboard necesita para iniciarla
# con whatsappCalls/call. Se incluye en Assistant::Executor.
module Assistant::CallRunner
  def run_whatsapp_call(payload)
    conversation = @tools.callable!(@tools.find_conversation(payload['conversation_id']))
    contact = conversation.contact
    done("Llamando a #{contact.name} por WhatsApp", "#{base}/conversations/#{conversation.display_id}")
      .merge('call' => { 'id' => conversation.display_id, 'inbox_id' => conversation.inbox_id,
                         'meta' => { 'sender' => { 'name' => contact.name, 'phone_number' => contact.phone_number,
                                                   'thumbnail' => contact.avatar_url } } })
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end
end
