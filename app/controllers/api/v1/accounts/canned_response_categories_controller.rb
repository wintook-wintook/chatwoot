# frozen_string_literal: true

# ================================================================================
# proyecto@respuestas_predefinidas R3 — CATEGORÍAS DE RESPUESTAS PREDEFINIDAS
# ================================================================================
#   GET    …/canned_response_categories               → [{ id, name, description, canned_count }]
#   POST   …/canned_response_categories               { name, description, canned_ids? }
#          canned_ids: las predefinidas que entran (aceptar una sugerencia)
#   PATCH  …/canned_response_categories/:id           { name, description }
#   DELETE …/canned_response_categories/:id           sus predefinidas quedan sin categoría
#   GET    …/canned_response_categories/suggestions   (D3) CannedResponses::CategorySuggestions
# Mismo permiso que las respuestas predefinidas.
# ================================================================================

class Api::V1::Accounts::CannedResponseCategoriesController < Api::V1::Accounts::BaseController
  MAX_ASSIGN = 100
  before_action :fetch_category, only: [:update, :destroy]

  def index
    conteos = Current.account.canned_responses.where.not(category_id: nil).group(:category_id).count
    render json: categories.order(:name).map { |c| payload(c, conteos[c.id].to_i) }
  end

  def create
    ids = Array(params[:canned_ids]).map(&:to_i).uniq.first(MAX_ASSIGN)
    categoria = categories.new(category_params)
    ActiveRecord::Base.transaction do
      categoria.save!
      Current.account.canned_responses.where(id: ids).find_each { |r| r.update!(category: categoria) }
    end
    render json: payload(categoria, categoria.canned_responses.count)
  end

  def update
    @category.update!(category_params)
    render json: payload(@category, @category.canned_responses.count)
  end

  def destroy
    @category.destroy!
    head :ok
  end

  def suggestions
    render json: CannedResponses::CategorySuggestions.new(Current.account).call
  end

  private

  def categories = Current.account.canned_response_categories

  def fetch_category
    @category = categories.find(params[:id])
  end

  def category_params
    params.require(:canned_response_category).permit(:name, :description)
  end

  def payload(categoria, cuantas)
    categoria.as_json(only: %i[id name description created_at updated_at]).merge('canned_count' => cuantas)
  end
end
