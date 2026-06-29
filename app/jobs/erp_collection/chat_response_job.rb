# frozen_string_literal: true

# @query_databases — Modo B (reactivo): ante un mensaje ENTRANTE en una conversación
# cuyo inbox tiene un bot con mode_b_enabled, traduce la pregunta a una consulta
# predefinida (AiQueryService) y responde en la conversación. Solo lectura.
class ErpCollection::ChatResponseJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless respondable?(message)

    conversation = message.conversation
    bot = find_bot(conversation)
    return if bot&.external_db_connection.nil?

    reply(conversation, bot, message.content)
  rescue StandardError => e
    Rails.logger.error "[ErpCollection::ChatResponse] #{e.class}: #{e.message}"
  end

  private

  def respondable?(message)
    message.present? && message.incoming? && message.content.present?
  end

  def reply(conversation, bot, question)
    answer = ExternalDb::AiQueryService.new(bot.external_db_connection, question).perform.answer
    return if answer.blank?

    Messages::MessageBuilder.new(
      bot_user(conversation.account), conversation, { content: answer, private: false }
    ).perform
  end

  # Bot Modo B del inbox de la conversación (uno específico del inbox gana al global).
  def find_bot(conversation)
    conversation.account.erp_collection_bots.active
                .where(mode_b_enabled: true)
                .where(inbox_id: [conversation.inbox_id, nil])
                .order(Arel.sql('inbox_id IS NULL'))
                .first
  end

  def bot_user(account)
    account.administrators.first || account.users.first
  end
end
