# frozen_string_literal: true

# == Schema Information
#
# Table name: internal_chat_rooms
#
#  id              :bigint           not null, primary key
#  direct_key      :string
#  kind            :string           default("group"), not null
#  last_message_at :datetime
#  name            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  created_by_id   :bigint
#
# Indexes
#
#  index_internal_chat_rooms_on_account_id                 (account_id)
#  index_internal_chat_rooms_on_account_id_and_direct_key  (account_id,direct_key) UNIQUE WHERE (direct_key IS NOT NULL)
#  index_internal_chat_rooms_one_general                   (account_id,kind) UNIQUE WHERE ((kind)::text = 'general'::text)
#
# feat/chat_interno — UNA SALA DEL CHAT INTERNO
# ============================================================================
#   general  una por cuenta, de TODOS sus agentes (no lleva miembros fijos: la fila
#            de miembro solo guarda hasta dónde leyó cada uno)
#   direct   entre dos agentes; uno solo por pareja (direct_key «idMenor:idMayor»)
#   group    con nombre y miembros elegidos; lo administran su dueño y los administradores
# Plan: docs/chat_interno_plan.md §4 y §6
# ============================================================================
class InternalChatRoom < ApplicationRecord
  KINDS = %w[general direct group].freeze
  GENERAL_NAME = 'general'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :members, class_name: 'InternalChatMember', foreign_key: :room_id, dependent: :delete_all, inverse_of: :room
  has_many :users, through: :members
  has_many :messages, class_name: 'InternalChatMessage', foreign_key: :room_id, dependent: :delete_all, inverse_of: :room

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { maximum: 80 }, if: :group?

  # Las salas que ve un agente: la general y aquellas donde es miembro.
  scope :visible_to, lambda { |user|
    where(kind: 'general').or(where(id: InternalChatMember.where(user_id: user.id).select(:room_id)))
  }

  KINDS.each { |kind| define_method("#{kind}?") { self.kind == kind } }

  def self.general_for(account)
    find_or_create_by!(account: account, kind: 'general') { |room| room.name = GENERAL_NAME }
  rescue ActiveRecord::RecordNotUnique
    find_by!(account: account, kind: 'general')
  end

  def self.direct_key_for(*user_ids)
    user_ids.map(&:to_i).sort.join(':')
  end

  # A quiénes les llega lo que pasa en la sala (tiempo real, no leídos).
  def member_user_ids
    general? ? account.account_users.pluck(:user_id) : members.pluck(:user_id)
  end

  def accessible_by?(user)
    return account.account_users.exists?(user_id: user.id) if general?

    members.exists?(user_id: user.id)
  end

  # Renombrar y cambiar miembros: solo grupos, su dueño o un administrador de la cuenta.
  def manageable_by?(user, account_user)
    return false unless group?

    account_user&.administrator? || members.exists?(user_id: user.id, role: 'owner')
  end
end
