# frozen_string_literal: true

# == Schema Information
#
# Table name: internal_chat_members
#
#  id           :bigint           not null, primary key
#  last_read_at :datetime
#  muted        :boolean          default(FALSE), not null
#  role         :string           default("member"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  room_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_internal_chat_members_on_room_id_and_user_id  (room_id,user_id) UNIQUE
#  index_internal_chat_members_on_user_id              (user_id)
#
# feat/chat_interno — UN AGENTE EN UNA SALA DEL CHAT INTERNO
# En la sala general la fila se crea al leer por primera vez: solo sirve para los no leídos.
class InternalChatMember < ApplicationRecord
  ROLES = %w[owner member].freeze

  belongs_to :room, class_name: 'InternalChatRoom', inverse_of: :members
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :room_id }
end
