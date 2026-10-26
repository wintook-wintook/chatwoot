class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    # Plan-Roles-Permisos — «solo lo suyo» también en las conversaciones del contacto.
    @conversations = access_grant.conversations(Current.account.conversations).includes(
      :assignee, :contact, :inbox, :taggings
    ).where(inbox_id: inbox_ids, contact_id: @contact.id).order(id: :desc).limit(20)
  end

  private

  def inbox_ids
    if Current.user.administrator? || Current.user.agent?
      Current.user.assigned_inboxes.pluck(:id)
    else
      []
    end
  end
end
