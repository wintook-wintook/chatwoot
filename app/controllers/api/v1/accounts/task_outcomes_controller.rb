# frozen_string_literal: true

# Catálogos › Resultados de tareas. Todos lo leen; lo edita quien tiene Ajustes.
class Api::V1::Accounts::TaskOutcomesController < Api::V1::Accounts::BaseController
  before_action :set_outcome, only: %i[update destroy]

  def index
    render json: { task_outcomes: TaskOutcome.ensure_defaults_for(Current.account).map { |o| outcome_json(o) } }
  end

  def create
    outcome = Current.account.task_outcomes.new(outcome_params)
    outcome.position ||= Current.account.task_outcomes.count
    if outcome.save
      render json: { task_outcome: outcome_json(outcome) }, status: :created
    else
      render json: { error: outcome.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @outcome.update(outcome_params)
      render json: { task_outcome: outcome_json(@outcome) }
    else
      render json: { error: @outcome.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @outcome.destroy
    head :no_content
  end

  private

  def set_outcome
    @outcome = Current.account.task_outcomes.find(params[:id])
  end

  def outcome_params
    params.require(:task_outcome).permit(:label, :position, :active)
  end

  def outcome_json(outcome)
    outcome.slice(:id, :label, :position, :active)
  end
end
