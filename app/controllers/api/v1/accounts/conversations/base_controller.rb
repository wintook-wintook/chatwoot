class Api::V1::Accounts::Conversations::BaseController < Api::V1::Accounts::BaseController
  before_action :conversation

  private

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation.inbox, :show?
    # Plan-Roles-Permisos — quien ve solo lo suyo no abre las de otros por URL.
    render_access_denied unless access_grant.conversation_visible?(@conversation)
  end
end
