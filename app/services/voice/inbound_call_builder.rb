# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — CREAR UNA LLAMADA ENTRANTE
# ================================================================================
# Contacto y conversación con el MISMO criterio que un mensaje de WhatsApp
# (Whatsapp::IncomingMessageBaseService#set_contact / #set_conversation): la llamada cae
# en la conversación donde ya se platica. Luego la fila de la llamada y su burbuja, todo
# en una transacción. Si Meta reintenta el mismo connect, se devuelve la que ya existe.
# Portado de la v4.19 sin Twilio ni push VoIP.
# ================================================================================
class Voice::InboundCallBuilder
  pattr_initialize [:inbox!, :call_id!, :wa_id!, :contact_name, :extra_meta]

  def perform!
    existing = find_existing
    return existing if existing

    ActiveRecord::Base.transaction do
      contact_inbox = find_or_create_contact_inbox
      call = Call.create!(
        account: inbox.account, inbox: inbox, contact: contact_inbox.contact,
        conversation: find_or_create_conversation(contact_inbox),
        provider: :whatsapp, direction: :incoming, status: 'ringing', provider_call_id: call_id,
        meta: { 'initiated_at' => Time.zone.now.to_i }.merge((extra_meta || {}).stringify_keys)
      )
      call.update!(message: Voice::CallMessageBuilder.new(call).perform!)
      call
    end
  rescue ActiveRecord::RecordNotUnique
    # Un reintento de Meta ganó la carrera: se devuelve la que ya quedó.
    find_existing || raise
  end

  private

  def find_existing
    Call.whatsapp.find_by(provider_call_id: call_id)
  end

  def find_or_create_contact_inbox
    ::ContactInboxWithContactBuilder.new(
      source_id: wa_id, inbox: inbox,
      contact_attributes: { name: contact_name.presence || "+#{wa_id}", phone_number: "+#{wa_id}" }
    ).perform
  end

  def find_or_create_conversation(contact_inbox)
    reusable = if inbox.lock_to_single_conversation
                 contact_inbox.conversations.last
               else
                 contact_inbox.conversations.where.not(status: :resolved).last
               end
    reusable || ::Conversation.create!(account_id: inbox.account_id, inbox_id: inbox.id,
                                       contact_id: contact_inbox.contact_id, contact_inbox_id: contact_inbox.id)
  end
end
