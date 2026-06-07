# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2K
# ================================================================================
# Controller: Api::V1::Accounts::CaseTypeFieldsController
# Campos personalizados de un tipo de caso (anidado bajo case_types).
#
# GET    /api/v1/accounts/:account_id/case_types/:case_type_id/fields
# POST   /api/v1/accounts/:account_id/case_types/:case_type_id/fields
# PATCH  /api/v1/accounts/:account_id/case_types/:case_type_id/fields/:id
# DELETE /api/v1/accounts/:account_id/case_types/:case_type_id/fields/:id
# ================================================================================

class Api::V1::Accounts::CaseTypeFieldsController < Api::V1::Accounts::BaseController
  before_action :set_case_type
  before_action :set_field, only: %i[update destroy]

  def index
    render json: { case_type_fields: @case_type.case_type_fields.ordered.map { |f| field_json(f) } }
  end

  def create
    field = @case_type.case_type_fields.build(field_params)
    field.account = Current.account
    field.position ||= @case_type.case_type_fields.count
    if field.save
      render json: { case_type_field: field_json(field) }, status: :created
    else
      render json: { error: field.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @field.update(field_params)
      render json: { case_type_field: field_json(@field) }
    else
      render json: { error: @field.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @field.destroy
    head :no_content
  end

  private

  def set_case_type
    @case_type = Current.account.case_types.find(params[:case_type_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tipo no encontrado' }, status: :not_found
  end

  def set_field
    @field = @case_type.case_type_fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Campo no encontrado' }, status: :not_found
  end

  def field_params
    params.require(:case_type_field).permit(:key, :label, :field_type, :required, :position, options: [])
  end

  def field_json(field)
    {
      id:         field.id,
      key:        field.key,
      label:      field.label,
      field_type: field.field_type,
      options:    field.options,
      required:   field.required,
      position:   field.position
    }
  end
end
