# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseTypesController
#
# GET    /api/v1/accounts/:account_id/case_types       → index (crea defaults si vacío)
# POST   /api/v1/accounts/:account_id/case_types       → create
# PATCH  /api/v1/accounts/:account_id/case_types/:id   → update
# DELETE /api/v1/accounts/:account_id/case_types/:id   → destroy
# ================================================================================

class Api::V1::Accounts::CaseTypesController < Api::V1::Accounts::BaseController
  before_action :set_type, only: %i[update destroy]

  def index
    types = CaseType.ensure_defaults_for(Current.account)
    render json: { case_types: types.map { |t| type_json(t) } }
  end

  def create
    type = Current.account.case_types.build(type_params)
    type.position ||= Current.account.case_types.count
    if type.save
      render json: { case_type: type_json(type) }, status: :created
    else
      render json: { error: type.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @type.update(type_params)
      render json: { case_type: type_json(@type) }
    else
      render json: { error: @type.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Los tickets asociados quedan con case_type_id = null (dependent: :nullify)
    @type.destroy
    head :no_content
  end

  private

  def set_type
    @type = Current.account.case_types.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tipo no encontrado' }, status: :not_found
  end

  def type_params
    params.require(:case_type).permit(:name, :color, :position, :prefix)
  end

  def type_json(type)
    {
      id:         type.id,
      name:       type.name,
      prefix:     type.prefix,
      color:      type.color,
      position:   type.position,
      created_at: type.created_at,
      updated_at: type.updated_at
    }
  end
end
