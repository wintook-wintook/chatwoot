# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2B
# ================================================================================
# Controller: Api::V1::Accounts::CaseCategoriesController
#
# GET    /api/v1/accounts/:account_id/case_categories       → index (con subcategorías)
# POST   /api/v1/accounts/:account_id/case_categories       → create (parent_id opcional)
# PATCH  /api/v1/accounts/:account_id/case_categories/:id   → update
# DELETE /api/v1/accounts/:account_id/case_categories/:id   → destroy (borra subcategorías)
# ================================================================================

class Api::V1::Accounts::CaseCategoriesController < Api::V1::Accounts::BaseController
  before_action :set_category, only: %i[update destroy]

  def index
    CaseCategory.ensure_defaults_for(Current.account)
    roots = Current.account.case_categories.roots.ordered.includes(:subcategories)
    render json: { case_categories: roots.map { |c| category_json(c) } }
  end

  def create
    category = Current.account.case_categories.build(category_params)
    category.position ||= Current.account.case_categories.where(parent_id: category.parent_id).count
    if category.save
      render json: { case_category: category_json(category) }, status: :created
    else
      render json: { error: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: { case_category: category_json(@category) }
    else
      render json: { error: @category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Los tickets asociados quedan con category_id = null (dependent: :nullify);
    # las subcategorías se eliminan en cascada (dependent: :destroy).
    @category.destroy
    head :no_content
  end

  private

  def set_category
    @category = Current.account.case_categories.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Categoría no encontrada' }, status: :not_found
  end

  def category_params
    permitted = params.require(:case_category).permit(:name, :active, :position, :parent_id)
    # parent_id debe pertenecer a la cuenta; si no, se ignora (queda raíz).
    if permitted[:parent_id].present?
      permitted[:parent_id] = Current.account.case_categories.where(id: permitted[:parent_id]).pick(:id)
    end
    permitted
  end

  def category_json(category)
    {
      id:            category.id,
      name:          category.name,
      parent_id:     category.parent_id,
      active:        category.active,
      position:      category.position,
      subcategories: category.subcategories.ordered.map { |s| category_json(s) },
      created_at:    category.created_at,
      updated_at:    category.updated_at
    }
  end
end
