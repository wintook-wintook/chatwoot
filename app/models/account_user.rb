# == Schema Information
#
# Table name: account_users
#
#  id               :bigint           not null, primary key
#  active_at        :datetime
#  auto_offline     :boolean          default(TRUE), not null
#  availability     :integer          default("online"), not null
#  field_profile    :jsonb            not null
#  role             :integer          default("agent")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  access_role_id   :bigint
#  account_id       :bigint
#  agent_contact_id :bigint
#  custom_role_id   :bigint
#  inviter_id       :bigint
#  user_id          :bigint
#
# Indexes
#
#  index_account_users_on_access_role_id    (access_role_id)
#  index_account_users_on_account_id        (account_id)
#  index_account_users_on_agent_contact_id  (agent_contact_id)
#  index_account_users_on_custom_role_id    (custom_role_id)
#  index_account_users_on_user_id           (user_id)
#  uniq_user_id_per_account_id              (account_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (access_role_id => access_roles.id) ON DELETE => nullify
#  fk_rails_...  (agent_contact_id => contacts.id)
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true
  # ================================================================================
  # proyecto@user_contact
  # ================================================================================
  belongs_to :agent_contact, class_name: 'Contact', optional: true
  # Plan-Roles-Permisos — sin rol = Supervisor (ver Access::Grant)
  belongs_to :access_role, optional: true
  # ================================================================================

  enum role: { agent: 0, administrator: 1 }
  enum availability: { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  # feat/chat_interno (plan v2): si la cuenta ya tiene «Interno», el agente nuevo entra a él.
  after_create_commit -> { InternalChannel::Setup.new(account).call if Channel::Internal.exists?(account_id: account_id) }
  after_destroy :notify_deletion, :remove_user_from_account, :remove_internal_chat_memberships
  after_save :update_presence_in_redis, if: :saved_change_to_availability?

  validates :user_id, uniqueness: { scope: :account_id }

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    setting.selected_push_flags = [:push_conversation_assignment]
    setting.save!
  end

  # feat/chat_interno: quien sale de la cuenta sale de sus conversaciones en «Interno».
  def remove_internal_chat_memberships
    inbox = account.internal_channel&.inbox
    ConversationParticipant.where(user_id: user_id, conversation_id: inbox.conversations.select(:id)).delete_all if inbox
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  # Plan-Roles-Permisos — `report_manage` abre Informes en el front (rutas de
  # Chatwoot) a los roles que tienen el área.
  def permissions
    return ['administrator'] if administrator?

    access_grant.allowed?(:reports) ? %w[agent report_manage] : ['agent']
  end

  def access_grant
    Access::Grant.for(self)
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  private

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
