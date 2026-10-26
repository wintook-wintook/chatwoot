# frozen_string_literal: true

# == Schema Information
#
# Table name: internal_chat_messages
#
#  id         :bigint           not null, primary key
#  content    :text
#  deleted_at :datetime
#  edited_at  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  room_id    :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_internal_chat_messages_on_room_id_and_id  (room_id,id)
#
# feat/chat_interno — UN MENSAJE DEL CHAT INTERNO
# Nunca se cruza con conversations/messages: no lo ven la IA, las automatizaciones ni los
# reportes. Al crearse, la sala sube en la lista (last_message_at) y les llega a sus
# miembros en tiempo real (InternalChat::Broadcaster, F2).
class InternalChatMessage < ApplicationRecord
  MAX_LENGTH = 5000

  belongs_to :room, class_name: 'InternalChatRoom', inverse_of: :messages
  belongs_to :user, optional: true

  validates :content, presence: true, length: { maximum: MAX_LENGTH }, unless: :deleted?

  after_create_commit :touch_room

  def deleted?
    deleted_at.present?
  end

  private

  def touch_room
    room.update_column(:last_message_at, created_at) # rubocop:disable Rails/SkipsModelValidations
  end
end
