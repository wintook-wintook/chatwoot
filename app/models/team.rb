# == Schema Information
#
# Table name: teams
#
#  id                :bigint           not null, primary key
#  allow_auto_assign :boolean          default(TRUE)
#  description       :text
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_teams_on_account_id           (account_id)
#  index_teams_on_name_and_account_id  (name,account_id) UNIQUE
#
class Team < ApplicationRecord
  include AccountCacheRevalidator

  belongs_to :account
  has_many :team_members, dependent: :destroy_async
  has_many :members, through: :team_members, source: :user
  has_many :conversations, dependent: :nullify
  has_one :internal_chat_room, dependent: :destroy # feat/chat_interno: la sala del equipo
  # feat/chat_interno (plan v2): cada equipo tiene su conversación en «Interno».
  after_create_commit -> { InternalChannel::Setup.new(account).sync_team(self) }
  after_destroy_commit :remove_internal_conversation

  validates :name,
            presence: { message: I18n.t('errors.validations.presence') },
            uniqueness: { scope: :account_id }

  before_validation do
    self.name = name.downcase if attribute_present?('name')
  end

  def add_member(user_id)
    team_members.find_or_create_by(user_id: user_id)&.user
  end

  def remove_member(user_id)
    team_members.find_by(user_id: user_id)&.destroy!
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  def push_event_data
    {
      id: id,
      name: name
    }
  end

  private

  def remove_internal_conversation
    inbox = account.internal_channel&.inbox
    inbox&.conversations&.where("additional_attributes -> 'internal' ->> 'key' = ?", "team:#{id}")&.destroy_all
  end
end

Team.include_mod_with('Audit::Team')
