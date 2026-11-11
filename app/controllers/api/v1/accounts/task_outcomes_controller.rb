# frozen_string_literal: true

# Catálogos › Resultados de tareas. Todos lo leen; lo edita quien tiene Ajustes.
# ?purpose=cancel: los motivos de cancelación (mismo catálogo, aparte de los resultados).
# PATCH /task_outcomes/settings { require_minutes } — exigir el tiempo dedicado en los
# reportes (encendido si nunca se tocó).
class Api::V1::Accounts::TaskOutcomesController < Api::V1::Accounts::BaseController
  before_action :set_outcome, only: %i[update destroy]

  def index
    render json: { task_outcomes: TaskOutcome.ensure_defaults_for(Current.account, purpose: purpose).map { |o| outcome_json(o) },
                   require_minutes: TaskReport.minutes_required?(Current.account) }
  end

  def settings
    account = Current.account
    account.custom_attributes = (account.custom_attributes || {}).merge(
      'report_minutes_required' => ActiveModel::Type::Boolean.new.cast(params[:require_minutes]) != false
    )
    account.save!
    render json: { require_minutes: TaskReport.minutes_required?(account) }
  end

  def create
    outcome = Current.account.task_outcomes.new(outcome_params.merge(purpose: purpose))
    outcome.position ||= Current.account.task_outcomes.where(purpose: purpose).count
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

  # report (resultados del reporte, como siempre) | cancel (motivos de cancelación)
  def purpose
    TaskOutcome.purposes.key?(params[:purpose].to_s) ? params[:purpose].to_s : 'report'
  end

  def set_outcome
    @outcome = Current.account.task_outcomes.find(params[:id])
  end

  def outcome_params
    params.require(:task_outcome).permit(:label, :position, :active)
  end

  def outcome_json(outcome)
    outcome.slice(:id, :label, :position, :active, :purpose)
  end
end
