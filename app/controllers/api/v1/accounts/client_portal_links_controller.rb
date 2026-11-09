# frozen_string_literal: true

# Portal del cliente — el enlace de una organización (o de un contacto sin organización).
#   GET  …/client_portal_link?organization_id= | contact_id=        → el vigente (o null)
#   POST …/client_portal_link        { organization_id | contact_id } → lo crea (o devuelve el vigente)
#   POST …/client_portal_link/renew  { … } → uno nuevo; el anterior deja de servir
#   POST …/client_portal_link/disable { … } → desactivarlo
# Ver: área Clientes; crear, renovar o desactivar: poder escribir en ella (AccessAreaGuard).
class Api::V1::Accounts::ClientPortalLinksController < Api::V1::Accounts::BaseController
  before_action :set_owner

  def show
    render json: { link: link_json(current_link) }
  end

  def create
    link = ClientPortalLink.for!(account: Current.account, user: current_user, **@owner)
    render json: { link: link_json(link) }
  end

  def renew
    link = current_link
    link = link ? link.renew!(current_user) : ClientPortalLink.for!(account: Current.account, user: current_user, **@owner)
    render json: { link: link_json(link) }
  end

  def disable
    current_link&.update!(active: false)
    render json: { link: nil }
  end

  private

  def set_owner
    @owner = if params[:organization_id].present?
               { organization: Current.account.organizations.find(params[:organization_id]) }
             else
               { contact: access_grant.contacts(Current.account.contacts).find(params[:contact_id]) }
             end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'No encontrado' }, status: :not_found
  end

  def current_link
    Current.account.client_portal_links.active.find_by(@owner)
  end

  def link_json(link)
    link && { url: link.url, created_at: link.created_at, last_used_at: link.last_used_at }
  end
end
