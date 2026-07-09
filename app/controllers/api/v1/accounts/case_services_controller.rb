# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2B
# ================================================================================
# Controller: Api::V1::Accounts::CaseServicesController
#
# GET    /api/v1/accounts/:account_id/case_services       → index (crea defaults si vacío)
# POST   /api/v1/accounts/:account_id/case_services       → create
# PATCH  /api/v1/accounts/:account_id/case_services/:id   → update
# DELETE /api/v1/accounts/:account_id/case_services/:id   → destroy
# ================================================================================

class Api::V1::Accounts::CaseServicesController < Api::V1::Accounts::BaseController
  before_action :set_service, only: %i[update destroy]

  def index
    services = CaseService.ensure_defaults_for(Current.account)
    render json: { case_services: services.map { |s| service_json(s) } }
  end

  def create
    service = Current.account.case_services.build(service_params)
    service.position ||= Current.account.case_services.count
    if service.save
      render json: { case_service: service_json(service) }, status: :created
    else
      render json: { error: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @service.update(service_params)
      render json: { case_service: service_json(@service) }
    else
      render json: { error: @service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Los tickets asociados quedan con affected_service_id = null (dependent: :nullify)
    @service.destroy
    head :no_content
  end

  private

  def set_service
    @service = Current.account.case_services.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Servicio no encontrado' }, status: :not_found
  end

  def service_params
    params.require(:case_service).permit(:name, :color, :active, :position)
  end

  def service_json(service)
    {
      id:         service.id,
      name:       service.name,
      color:      service.color,
      active:     service.active,
      position:   service.position,
      created_at: service.created_at,
      updated_at: service.updated_at
    }
  end
end
