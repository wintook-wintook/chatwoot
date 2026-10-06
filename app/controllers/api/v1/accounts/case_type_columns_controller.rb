# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Columnas del Kanban por Tipo de Caso (Opción A+)
# ================================================================================
# Controller: Api::V1::Accounts::CaseTypeColumnsController
# Columnas propias de un tipo de caso (anidado bajo case_types).
#
# GET    /api/v1/accounts/:account_id/case_types/:case_type_id/columns
# PUT    /api/v1/accounts/:account_id/case_types/:case_type_id/columns/replace  ◀ el que usa el panel
# POST   /api/v1/accounts/:account_id/case_types/:case_type_id/columns
# PATCH  /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:id
# DELETE /api/v1/accounts/:account_id/case_types/:case_type_id/columns/:id
# ================================================================================

class Api::V1::Accounts::CaseTypeColumnsController < Api::V1::Accounts::BaseController
  before_action :set_case_type
  before_action :set_column, only: %i[update destroy]

  def index
    render json: { case_type_columns: @case_type.case_type_columns.ordered.map { |c| column_json(c) } }
  end

  def create
    column = @case_type.case_type_columns.build(column_params)
    column.account = Current.account
    column.position ||= @case_type.case_type_columns.count
    if column.save
      render json: { case_type_column: column_json(column) }, status: :created
    else
      render json: { error: column.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @column.update(column_params)
      render json: { case_type_column: column_json(@column) }
    else
      render json: { error: @column.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @column.destroy # los tickets que apuntaban quedan con case_type_column_id = NULL
    head :no_content
  end

  # PUT /columns/replace — guarda el set completo del tipo en una transacción.
  def replace
    result = Cases::TypeColumnsReplaceService.new(
      case_type: @case_type,
      columns_params: replace_params
    ).call

    if result.success?
      render json: { case_type_columns: result.columns.map { |c| column_json(c) } }
    else
      render json: { error: result.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_case_type
    @case_type = Current.account.case_types.find(params[:case_type_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tipo no encontrado' }, status: :not_found
  end

  def set_column
    @column = @case_type.case_type_columns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Columna no encontrada' }, status: :not_found
  end

  def column_params
    params.require(:case_type_column).permit(:label, :color, :position, statuses: [])
  end

  def replace_params
    params.permit(columns: [:id, :label, :color, :position, { statuses: [] }])[:columns] || []
  end

  def column_json(column)
    {
      id: column.id,
      label: column.label,
      color: column.color,
      position: column.position,
      statuses: column.statuses
    }
  end
end
