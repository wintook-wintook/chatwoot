# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a: materiales de una orden
# ================================================================================
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/work_order_items
# PATCH  /api/v1/accounts/:id/case_tickets/:case_ticket_id/work_order_items/:id
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/work_order_items/:id
#
# La lista viaja en el JSON del caso (`work_order_items`); aquí solo se edita.
# Una orden cerrada o cancelada es de solo lectura (se reabre para cambiarla).
# ================================================================================

class Api::V1::Accounts::CaseWorkOrderItemsController < Api::V1::Accounts::BaseController
  FROZEN_MSG = 'Orden cerrada: no se pueden modificar los materiales. Reábrela si necesitas cambiarlos.'

  before_action :set_ticket
  before_action :reject_frozen
  before_action :set_item, only: %i[update destroy]

  def create
    item = @ticket.work_order_items.build(item_params)
    item.account = Current.account
    item.position ||= @ticket.work_order_items.count
    if item.save
      render json: { work_order_item: item_json(item) }, status: :created
    else
      render json: { error: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @item.update(item_params)
      render json: { work_order_item: item_json(@item) }
    else
      render json: { error: @item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    head :no_content
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Orden no encontrada' }, status: :not_found
  end

  def reject_frozen
    render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?
  end

  def set_item
    @item = @ticket.work_order_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Material no encontrado' }, status: :not_found
  end

  def item_params
    params.require(:work_order_item).permit(:description, :quantity, :unit, :unit_cost, :position)
  end

  def item_json(item)
    { id: item.id, description: item.description, quantity: item.quantity.to_f, unit: item.unit,
      unit_cost: item.unit_cost&.to_f, total: item.total&.to_f, position: item.position }
  end
end
