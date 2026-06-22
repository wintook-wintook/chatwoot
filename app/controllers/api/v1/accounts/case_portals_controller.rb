# frozen_string_literal: true

# ================================================================================
# @tickets_cases — User Portal (P1)
# ================================================================================
# Controller: Api::V1::Accounts::CasePortalsController
#
# GET    /api/v1/accounts/:account_id/case_portals       → index
# POST   /api/v1/accounts/:account_id/case_portals       → create (+ inbox Portal)
# PATCH  /api/v1/accounts/:account_id/case_portals/:id   → update
# DELETE /api/v1/accounts/:account_id/case_portals/:id   → destroy
# ================================================================================

class Api::V1::Accounts::CasePortalsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :set_portal, only: %i[update destroy]

  def index
    portals = Current.account.case_portals.order(:name)
    render json: { case_portals: portals.map { |p| portal_json(p) } }
  end

  def create
    portal = Current.account.case_portals.build(portal_params)
    if portal.save
      portal.ensure_inbox! # crea el inbox Channel::Api del portal de inmediato
      render json: { case_portal: portal_json(portal) }, status: :created
    else
      render json: { error: portal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @portal.update(portal_params)
      render json: { case_portal: portal_json(@portal) }
    else
      render json: { error: @portal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @portal.destroy
    head :no_content
  end

  private

  def set_portal
    @portal = Current.account.case_portals.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Portal no encontrado' }, status: :not_found
  end

  def portal_params
    params.require(:case_portal).permit(:name, :slug, :locale, :enabled, :intro, :custom_domain)
  end

  def portal_json(portal)
    {
      id:                 portal.id,
      name:               portal.name,
      slug:               portal.slug,
      locale:             portal.locale,
      enabled:            portal.enabled,
      intro:              portal.intro,
      custom_domain:      portal.custom_domain,
      inbox_id:           portal.inbox_id,
      public_path:        "/portal/#{portal.slug}",
      public_types_count: portal.public_case_types.count,
      created_at:         portal.created_at,
      updated_at:         portal.updated_at
    }
  end
end
