# frozen_string_literal: true

# Asistente (Dali) — lo que también espera al usuario, además de sus conversaciones sin
# responder (my_conversations los agrega cuando pregunta qué tiene pendiente):
#   • mentions: lo mencionaron con @ en una nota interna de una conversación con cliente y no
#     ha escrito nada en ella desde entonces (abierta o pendiente);
#   • internal_chat: salas del chat interno con mensajes sin leer (y si alguno lo menciona);
#   • unassigned: solo a quien reparte (puede reasignar): conversaciones sin asignar que
#     esperan respuesta, por bandeja, sin la bandeja «Interno».
# propose_internal_note: contestarle al equipo con una nota interna en la conversación (al
# cliente no le llega). En el chat interno se contesta con propose_reply.
# Se incluye en Assistant::Tools.
module Assistant::PendingTools
  PENDING_PROPOSAL_TOOLS = %w[propose_internal_note].freeze
  MENTION_LIMIT = 10
  MENTION_MARKUP = %r{\[([^\]]*)\]\(mention://(?:user|team)/\d+/[^)]*\)}

  def pending_blocks
    { mentions: pending_mentions, internal_chat: internal_unread,
      unassigned: (unassigned_waiting if @grant.can?(:reassign)) }.reject { |_, v| v.blank? }
  end

  def prepare_internal_note(args)
    conversation = find_conversation(args['conversation_id'])
    raise ArgumentError, 'En el chat interno se contesta con un mensaje (propose_reply).' if conversation.internal?
    raise ArgumentError, 'Falta el texto de la nota.' if args['content'].blank?

    [{ 'conversation_id' => conversation.display_id, 'content' => args['content'].to_s.strip },
     { 'conversation' => conversation_label(conversation) }]
  end

  # Las conversaciones con clientes que el usuario ve (sin las salas del chat interno).
  def customer_conversations
    @grant.conversations(@account.conversations).where.not(inbox_id: internal_inbox_ids)
  end

  def internal_inbox_ids
    @internal_inbox_ids ||= InternalChannel::Access.internal_inbox_ids(@account)
  end

  # «# general», «# Ventas» o el nombre del compañero en un directo.
  def room_name(room)
    info = room.additional_attributes.to_h['internal'] || {}
    case info['kind']
    when 'general' then '# general'
    when 'team' then "# #{@account.teams.find_by(id: info['team_id'])&.name}"
    else direct_name(room)
    end
  end

  def direct_name(room)
    room.conversation_participants.where.not(user_id: @user.id).first&.user&.name || 'Directo'
  end

  def clean_mentions(text)
    text.to_s.gsub(MENTION_MARKUP, '\1')
  end

  private

  def pending_mentions
    mentions = Mention.where(account_id: @account.id, user_id: @user.id)
                      .where(conversation_id: customer_conversations.where(status: %i[open pending]).select(:id))
                      .includes(conversation: %i[contact inbox]).order(mentioned_at: :desc).limit(MENTION_LIMIT * 3)
    mentions.reject { |m| written_since?(m.conversation, m.mentioned_at) }.first(MENTION_LIMIT).map { |m| mention_row(m) }
  end

  def written_since?(conversation, at)
    conversation.messages.where(sender_type: 'User', sender_id: @user.id).exists?(['messages.created_at > ?', at])
  end

  def mention_row(mention)
    conversation = mention.conversation
    note = conversation.messages.where(private: true).where('messages.content LIKE ?', "%mention://user/#{@user.id}/%")
                       .where('messages.created_at <= ?', mention.mentioned_at + 1.minute).includes(:sender).order(:created_at).last
    { id: conversation.display_id, contact: conversation.contact&.name, inbox: conversation.inbox&.name,
      by: mention_author(note), note: note && clean_mentions(note.content).truncate(200), at: local(mention.mentioned_at) }.compact
  end

  # Una nota a su propio nombre con su mención es un aviso automático (p. ej. del Seguimiento IA).
  def mention_author(note)
    return if note.nil?

    note.sender == @user ? 'aviso automático' : note.sender&.name
  end

  def internal_unread
    return [] if internal_inbox_ids.empty? || !@account.internal_chat_enabled?

    rooms = Conversation.where(inbox_id: internal_inbox_ids).where(id: InternalChannel::Access.participant_ids(@user))
    rooms.filter_map { |room| internal_row(room) }
  end

  def internal_row(room)
    unread = InternalChannel::Access.unread_count(room, @user)
    return if unread.zero?

    last = InternalChannel::Access.from_others(room, @user).includes(:sender).last
    { id: room.display_id, room: room_name(room), unread: unread, mentions_you: (true if mentions_me_unread?(room)),
      last: last && { from: last.sender&.name, text: clean_mentions(last.content).truncate(160), at: local(last.created_at) } }.compact
  end

  def mentions_me_unread?(room)
    read_at = room.conversation_participants.find_by(user_id: @user.id)&.last_read_at
    scope = InternalChannel::Access.from_others(room, @user).where('messages.content LIKE ?', "%mention://user/#{@user.id}/%")
    scope = scope.where('messages.created_at > ?', read_at) if read_at
    scope.exists?
  end

  # Sin asignar y esperando respuesta: cuántas por bandeja y desde cuándo la más vieja.
  def unassigned_waiting
    scope = customer_conversations.open.where(assignee_id: nil).where.not(waiting_since: nil)
    total = scope.count
    return if total.zero?

    { total: total, oldest_waiting_since: local(scope.minimum(:waiting_since)),
      by_inbox: scope.joins(:inbox).group('inboxes.name').count.map { |name, count| { inbox: name, count: count } } }
  end
end
