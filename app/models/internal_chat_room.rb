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
#  team_id         :bigint
#
# Indexes
#
#  index_internal_chat_rooms_on_account_id                 (account_id)
#  index_internal_chat_rooms_on_account_id_and_direct_key  (account_id,direct_key) UNIQUE WHERE (direct_key IS NOT NULL)
#  index_internal_chat_rooms_on_account_id_and_team_id     (account_id,team_id) UNIQUE WHERE (team_id IS NOT NULL)
#  index_internal_chat_rooms_one_general                   (account_id,kind) UNIQUE WHERE ((kind)::text = 'general'::text)
#
# feat/chat_interno — UNA SALA DEL CHAT INTERNO
# ============================================================================
#   general  una por cuenta, de TODOS sus agentes
#   team     una por EQUIPO de Chatwoot, de los miembros del equipo (los grupos del chat
#            son los equipos: se arman y cambian en Ajustes → Equipos)
#   direct   entre dos agentes; uno solo por pareja (direct_key «idMenor:idMayor»)
# En general y team la fila de miembro solo guarda hasta dónde leyó cada uno: quién está lo
# dicen la cuenta y el equipo. Plan: docs/chat_interno_plan.md §4 y §6
# ============================================================================
class InternalChatRoom < ApplicationRecord
  KINDS = %w[general team direct].freeze
  GENERAL_NAME = 'general'

  belongs_to :account
  belongs_to :team, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :members, class_name: 'InternalChatMember', foreign_key: :room_id, dependent: :delete_all, inverse_of: :room
  has_many :users, through: :members
  has_many :messages, class_name: 'InternalChatMessage', foreign_key: :room_id, dependent: :delete_all, inverse_of: :room

  validates :kind, inclusion: { in: KINDS }
  validates :team_id, presence: true, if: :team?

  # Las salas que ve un agente: la general, las de sus equipos y sus directos.
  scope :visible_to, lambda { |user|
    where(kind: 'general')
      .or(where(kind: 'team', team_id: user.team_members.select(:team_id)))
      .or(where(kind: 'direct', id: InternalChatMember.where(user_id: user.id).select(:room_id)))
  }

  KINDS.each { |kind| define_method("#{kind}?") { self.kind == kind } }

  def self.general_for(account)
    find_or_create_by!(account: account, kind: 'general') { |room| room.name = GENERAL_NAME }
  rescue ActiveRecord::RecordNotUnique
    find_by!(account: account, kind: 'general')
  end

  # Una sala por equipo (los equipos nuevos la reciben la próxima vez que alguien entra).
  def self.ensure_team_rooms!(account)
    existing = where(account: account, kind: 'team').pluck(:team_id)
    account.teams.where.not(id: existing).find_each do |team|
      create!(account: account, kind: 'team', team: team)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end

  def self.direct_key_for(*user_ids)
    user_ids.map(&:to_i).sort.join(':')
  end

  def display_name
    team? ? team&.name : name
  end

  # Quiénes están en la sala: les llega lo que pasa en ella (tiempo real, no leídos).
  def member_users
    return account.users if general?
    return team ? team.members : User.none if team?

    users
  end

  def member_user_ids
    member_users.pluck(:id)
  end

  def accessible_by?(user)
    return account.account_users.exists?(user_id: user.id) if general?
    return team.present? && team.team_members.exists?(user_id: user.id) if team?

    members.exists?(user_id: user.id)
  end
end
