# frozen_string_literal: true

# feat/chat_interno (plan v2, R1) — ABRIR UN DIRECTO EN «INTERNO»
# La conversación privada entre dos agentes de la cuenta (si ya existe, la misma).
class InternalChannel::Direct
  class Error < StandardError; end

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def open!(other_user_id)
    other = other_user_id.to_i
    raise Error, 'invalid_user' if other == @user.id || !@account.account_users.exists?(user_id: other)

    setup = InternalChannel::Setup.new(@account)
    raise Error, 'internal_chat_disabled' if setup.call.nil?

    key = "direct:#{[@user.id, other].sort.join(':')}"
    setup.conversation_for(kind: 'direct', key: key, user_ids: [@user.id, other])
  end
end
