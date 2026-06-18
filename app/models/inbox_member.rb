# == Schema Information
#
# Table name: inbox_members
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  inbox_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_inbox_members_on_inbox_id              (inbox_id)
#  index_inbox_members_on_inbox_id_and_user_id  (inbox_id,user_id) UNIQUE
#

class InboxMember < ApplicationRecord
  validates :inbox_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :inbox_id }

  belongs_to :user
  belongs_to :inbox

  # Reconstruimos la cola Redis completa desde la DB en cada alta/baja en lugar de
  # hacer lpush/lrem incremental: el add/remove incremental se desincroniza si Redis
  # se reinicia o falla un callback, dejando el inbox "sin recibir" hasta quitar y
  # volver a agregar colaboradores. reset_queue limpia y reconstruye la cola desde
  # los inbox_members de la DB, así queda siempre exactamente igual que la DB.
  after_create :sync_round_robin_queue
  after_destroy :sync_round_robin_queue

  private

  def sync_round_robin_queue
    return if inbox.blank?

    ::AutoAssignment::InboxRoundRobinService.new(inbox: inbox).reset_queue
  end
end

InboxMember.include_mod_with('Audit::InboxMember')
