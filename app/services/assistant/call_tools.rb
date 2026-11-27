# frozen_string_literal: true

# Asistente (Dali) — llamar a un cliente por WhatsApp. La tarjeta no llama: al confirmar, la
# llamada sale del navegador del usuario (WebRTC, store whatsappCalls/call) con el mismo widget
# que el botón «Llamar» de la conversación. Mismas reglas que Api::V1::Accounts::WhatsappCallsController:
# bandeja de WhatsApp con salientes y usuario de la bandeja o administrador (P4). El permiso del
# cliente lo pide la llamada misma (Whatsapp::CallPermissionRequestService).
# Se incluye en Assistant::Tools; lo confirmado lo arma Assistant::CallRunner.
module Assistant::CallTools
  CALL_PROPOSAL_TOOLS = %w[propose_whatsapp_call].freeze

  def prepare_whatsapp_call(args)
    conversation = call_conversation(args)
    callable!(conversation)
    contact = conversation.contact
    [{ 'conversation_id' => conversation.display_id },
     { 'target' => contact.name, 'rows' => [['PHONE', contact.phone_number.presence || '—'], ['INBOX', conversation.inbox.name]] }]
  end

  # Levanta ArgumentError con el motivo si este usuario no puede llamar desde esa conversación.
  def callable!(conversation)
    inbox = conversation.inbox
    raise ArgumentError, 'Esa conversación no es de WhatsApp: solo se llama por WhatsApp.' unless inbox.channel_type == 'Channel::Whatsapp'
    raise ArgumentError, "La bandeja «#{inbox.name}» no tiene activadas las llamadas salientes." unless inbox.channel.try(:outbound_calls_allowed?)
    raise ArgumentError, 'Solo los usuarios de esa bandeja y los administradores pueden llamar desde ahí.' unless call_member?(inbox)

    conversation
  end

  private

  # La conversación dada, o la de WhatsApp más reciente del contacto (o del cliente del caso)
  # en una bandeja desde la que este usuario puede llamar.
  def call_conversation(args)
    return find_conversation(args['conversation_id']) if args['conversation_id'].present?

    contact = call_contact(args)
    @grant.conversations(@account.conversations).where(contact_id: contact.id, inbox_id: callable_inbox_ids)
          .order(last_activity_at: :desc).first ||
      raise(ArgumentError, "#{contact.name} no tiene una conversación de WhatsApp en una bandeja con llamadas. " \
                           'Para llamarle por primera vez, escríbele por WhatsApp.')
  end

  def call_contact(args)
    return contacts.find(args['contact_id']) if args['contact_id'].present?

    contact = cases.find(args['case_id']).contact if args['case_id'].present?
    contact || raise(ArgumentError, 'Dime a quién le llamo (el cliente, su caso o la conversación).')
  end

  def callable_inbox_ids
    @account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel)
            .select { |inbox| inbox.channel.try(:outbound_calls_allowed?) && call_member?(inbox) }.map(&:id)
  end

  def call_member?(inbox) = @grant.admin? || inbox.members.exists?(id: @user.id)
end
