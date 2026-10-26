# == Schema Information
#
# Table name: team_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_team_members_on_team_id              (team_id)
#  index_team_members_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_team_members_on_user_id              (user_id)
#
class TeamMember < ApplicationRecord
  belongs_to :user
  belongs_to :team
  validates :user_id, uniqueness: { scope: :team_id }

  # feat/chat_interno (plan v2): la conversación del equipo en «Interno» sigue a sus miembros.
  after_commit :sync_internal_conversation, on: [:create, :destroy]

  private

  def sync_internal_conversation
    InternalChannel::Setup.new(team.account).sync_team(team) if team.present?
  end
end

TeamMember.include_mod_with('Audit::TeamMember')
