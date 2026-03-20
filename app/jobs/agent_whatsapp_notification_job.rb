# ================================================================================
# proyecto@user_contact
# ================================================================================
class AgentWhatsappNotificationJob < ApplicationJob
  queue_as :default

  def perform(account_id:, user_id:, message:, inbox_id: nil)
    account = Account.find(account_id)
    user = User.find(user_id)
    inbox = inbox_id ? Inbox.find_by(id: inbox_id) : nil

    Agents::WhatsappNotificationService.new(
      account: account,
      user: user,
      message: message,
      inbox: inbox
    ).perform
  end
end
