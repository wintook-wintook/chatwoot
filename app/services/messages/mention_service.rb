class Messages::MentionService
  pattr_initialize [:message!]

  def perform
    return unless valid_mention_message?(message)

    validated_mentioned_ids = filter_mentioned_ids_by_inbox
    return if validated_mentioned_ids.blank?

    Conversations::UserMentionJob.perform_later(validated_mentioned_ids, message.conversation.id, message.account.id)
    generate_notifications_for_mentions(validated_mentioned_ids)
    add_mentioned_users_as_participants(validated_mentioned_ids)
  end

  private

  def valid_mention_message?(message)
    # feat/chat_interno: en «Interno» los mensajes no son notas privadas y también avisan.
    (message.private? || internal?) && message.content.present? && mentioned_ids.present?
  end

  def mentioned_ids
    @mentioned_ids ||= message.content.scan(%r{\(mention://(user|team)/(\d+)/(.+?)\)}).map(&:second).uniq
  end

  def filter_mentioned_ids_by_inbox
    inbox = message.inbox
    valid_mentionable_ids = inbox.account.administrators.map(&:id) + inbox.members.map(&:id)
    # En «Interno» solo quien ya está en la sala: un directo o el grupo de un equipo es privado.
    valid_mentionable_ids &= message.conversation.conversation_participants.pluck(:user_id) if internal?
    # Intersection of ids
    mentioned_ids & valid_mentionable_ids.uniq.map(&:to_s)
  end

  def internal?
    message.conversation.respond_to?(:internal?) && message.conversation.internal?
  end

  def generate_notifications_for_mentions(validated_mentioned_ids)
    validated_mentioned_ids.each do |user_id|
      NotificationBuilder.new(
        notification_type: 'conversation_mention',
        user: User.find(user_id),
        account: message.account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  def add_mentioned_users_as_participants(validated_mentioned_ids)
    return if internal?

    validated_mentioned_ids.each do |user_id|
      message.conversation.conversation_participants.find_or_create_by(user_id: user_id)
    end
  end
end
