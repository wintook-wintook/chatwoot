# frozen_string_literal: true

# Asistente (Dali) — contestar las conversaciones con clientes platicando.
#
#   my_conversations(filter)          → las abiertas asignadas al usuario; por omisión las que
#                                       esperan respuesta (waiting_since), la que más lleva primero
#   read_conversation(conversation_id) → los últimos mensajes, si se puede escribir libre y, si
#                                       no (ventana de 24 h de WhatsApp cerrada), las plantillas
#   propose_reply                     → tarjeta con el texto (editable) o la plantilla llena; al
#                                       confirmar sale por el canal de la conversación, a nombre
#                                       del usuario (Assistant::ConversationRunner)
#
# Solo conversaciones que el usuario ve (Access::Grant#conversations); contestar pide
# permiso de escribir en Conversaciones. Se incluye en Assistant::Tools.
module Assistant::ConversationTools
  CONVERSATION_READ_TOOLS = %w[my_conversations read_conversation].freeze
  CONVERSATION_PROPOSAL_TOOLS = %w[propose_reply].freeze
  INBOX_LIMIT = 10
  READ_MESSAGES = 15
  TEMPLATE_LIMIT = 8

  # Por omisión, además, lo pendiente del usuario: menciones, chat interno y (a quien reparte)
  # las sin asignar (Assistant::PendingTools).
  def tool_my_conversations(args)
    scope = customer_conversations.open.where(assignee_id: @user.id)
    scope = scope.where.not(waiting_since: nil) unless args['filter'] == 'open'
    rows = scope.includes(:contact, :inbox).order(Arel.sql('waiting_since ASC NULLS LAST'), last_activity_at: :desc)
                .limit(INBOX_LIMIT)
    result = { total: scope.count, conversations: rows.map { |c| inbox_row(c) } }
    args['filter'] == 'open' ? result : result.merge(pending_blocks)
  end

  def tool_read_conversation(args)
    conversation = find_conversation(args['conversation_id'])
    return internal_room(conversation) if conversation.internal?

    can_reply = conversation.can_reply?
    { id: conversation.display_id, contact: conversation.contact && contact_ref(conversation.contact),
      inbox: conversation.inbox&.name, status: conversation.status, assignee: conversation.assignee&.name,
      can_reply: can_reply, messages: recent_messages(conversation),
      templates: (reply_templates(conversation) unless can_reply) }.compact
  end

  def prepare_reply(args)
    conversation = find_conversation(args['conversation_id'])
    raise ArgumentError, 'No tienes permiso para contestar conversaciones.' unless conversation.internal? || @grant.writable?(:conversations)

    return template_reply(conversation, args) if args['template_name'].present?
    raise ArgumentError, closed_window_message(conversation) unless conversation.can_reply?
    raise ArgumentError, 'Falta el texto de la respuesta.' if args['content'].blank?

    [{ 'conversation_id' => conversation.display_id, 'content' => args['content'].to_s.strip },
     { 'conversation' => conversation_label(conversation) }]
  end

  # Una conversación que el usuario ve, por su número (también la usan el mensaje programado y el borrador).
  # Una sala del chat interno, solo si participa en ella.
  def find_conversation(display_id)
    conversation = @grant.conversations(@account.conversations).find_by(display_id: display_id)
    conversation = nil if conversation && !InternalChannel::Access.can_see?(conversation, @user)
    raise ArgumentError, 'No encontré esa conversación o no tienes acceso.' unless conversation

    conversation
  end

  # La plantilla llena (lo mismo que hará el envío) → { content:, template_params:, template: }.
  def fill_reply_template(conversation, payload)
    filled = AiFollowUps::Templates.new(conversation)
                                   .fill(payload['template_name'], payload['template_language'], payload['template_values'].to_h)
    raise ArgumentError, filled[:error] if filled[:error]

    filled
  end

  private

  # Chat interno: la sala, sus mensajes y queda leída (Dali se la leyó).
  def internal_room(room)
    InternalChannel::Access.mark_read!(room, @user)
    { id: room.display_id, room: room_name(room), internal_chat: true, can_reply: true,
      messages: recent_messages(room).map { |m| m.merge(text: clean_mentions(m[:text])) } }
  end

  def template_reply(conversation, args)
    filled = fill_reply_template(conversation, args)
    template = filled[:template]
    [{ 'conversation_id' => conversation.display_id, 'template_name' => template[:name],
       'template_language' => template[:language], 'template_values' => args['template_values'].to_h },
     { 'conversation' => conversation_label(conversation), 'template' => template[:name], 'template_text' => filled[:content] }]
  end

  def closed_window_message(conversation)
    names = reply_templates(conversation).pluck(:name)
    return 'Pasaron más de 24 h desde su último mensaje y esta bandeja no tiene plantillas aprobadas: no se le puede escribir.' if names.empty?

    "Pasaron más de 24 h desde su último mensaje: solo se puede mandar una plantilla aprobada (#{names.join(', ')}). " \
      'Ofrécele al usuario la que encaje y llama propose_reply con template_name y sus variables.'
  end

  def reply_templates(conversation)
    AiFollowUps::Templates.new(conversation).available.first(TEMPLATE_LIMIT)
                          .map { |t| t.slice(:name, :language, :body, :variables) }
  end

  def inbox_row(conversation)
    last = conversation.messages.where(message_type: %i[incoming outgoing], private: false).last
    { id: conversation.display_id, contact: conversation.contact&.name, inbox: conversation.inbox&.name,
      waiting_since: local(conversation.waiting_since),
      last_message: last && { from: last.incoming? ? 'cliente' : 'nosotros', text: message_text(last).truncate(160), at: local(last.created_at) } }
  end

  def recent_messages(conversation)
    conversation.messages.where(message_type: %i[incoming outgoing]).includes(:sender, :attachments)
                .order(created_at: :desc).limit(READ_MESSAGES).reverse.map do |m|
      { from: message_author(m), at: local(m.created_at), text: message_text(m).truncate(500), internal_note: (true if m.private?) }.compact
    end
  end

  def message_author(message)
    return message.conversation.contact&.name || 'cliente' if message.incoming?

    message.sender.respond_to?(:name) ? message.sender.name : 'nosotros'
  end

  def message_text(message)
    text = message.content.to_s.strip
    files = message.attachments.filter_map(&:file_type)
    text = [text, "[#{files.join(', ')}]"].compact_blank.join(' ') if files.any?
    text.presence || '[sin texto]'
  end
end
