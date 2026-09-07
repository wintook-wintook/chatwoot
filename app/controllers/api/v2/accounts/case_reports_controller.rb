# proyecto@metricas_casos — Informes de Casos (seguimiento de oportunidades por
# vendedor). Vive aparte de Api::V2::Accounts::ReportsController porque el dominio
# (CaseTicket) no tiene reporting_events ni comparte builders con Conversation.
class Api::V2::Accounts::CaseReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def funnel
    render json: distribution_builder.funnel
  end

  def outcome
    render json: distribution_builder.outcome
  end

  def timeseries
    render json: timeseries_builder.timeseries
  end

  def assignees
    render json: assignee_summary_builder.build
  end

  def velocity
    render json: stage_duration_builder.velocity
  end

  def stalled
    render json: stage_duration_builder.stalled(threshold_days: threshold_days_param)
  end

  private

  def distribution_builder
    @distribution_builder ||= V2::Reports::Cases::DistributionBuilder.new(account: Current.account, params: permitted_params)
  end

  def timeseries_builder
    @timeseries_builder ||= V2::Reports::Cases::TimeseriesBuilder.new(account: Current.account, params: timeseries_params)
  end

  def assignee_summary_builder
    @assignee_summary_builder ||= V2::Reports::Cases::AssigneeSummaryBuilder.new(account: Current.account, params: permitted_params)
  end

  def stage_duration_builder
    @stage_duration_builder ||= V2::Reports::Cases::StageDurationBuilder.new(account: Current.account, params: permitted_params)
  end

  def threshold_days_param
    params[:threshold_days].presence || V2::Reports::Cases::StageDurationBuilder::DEFAULT_THRESHOLD_DAYS
  end

  def permitted_params
    params.permit(:case_type_id, :assignee_id, :team_id, :since, :until, :threshold_days)
  end

  def timeseries_params
    params.permit(:case_type_id, :assignee_id, :team_id, :since, :until, :group_by, :timezone_offset)
  end

  def check_authorization
    authorize :report, :view?
  end
end
