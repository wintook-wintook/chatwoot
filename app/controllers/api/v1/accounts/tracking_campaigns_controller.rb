# @campanas_vendedor
# frozen_string_literal: true

# ================================================================================
# Controller: TrackingCampaignsController
# ================================================================================
# Listado de campañas (corridas de asignación masiva de seguimientos) para el
# Dashboard de Seguimientos. Cada campaña agrupa sus ContactTracking; las
# estadísticas se agregan en una sola consulta para evitar N+1.
#
# GET /api/v1/accounts/:account_id/tracking_campaigns        → listado con stats
# GET /api/v1/accounts/:account_id/tracking_campaigns/:id     → una campaña con stats
# ================================================================================

class Api::V1::Accounts::TrackingCampaignsController < Api::V1::Accounts::BaseController
  def index
    campaigns = Current.account.tracking_campaigns
                       .includes(:tracking_template, :inbox)
                       .order(created_at: :desc)
    stats = stats_by_campaign(campaigns.map(&:id))

    render json: campaigns.map { |campaign| campaign_json(campaign, stats[campaign.id]) }
  end

  def show
    campaign = Current.account.tracking_campaigns.find(params[:id])
    stats = stats_by_campaign([campaign.id])

    render json: campaign_json(campaign, stats[campaign.id])
  end

  private

  # { campaign_id => { 'pending' => N, 'active' => N, ... } } en una sola query
  def stats_by_campaign(ids)
    return {} if ids.blank?

    grouped = ContactTracking.where(tracking_campaign_id: ids).group(:tracking_campaign_id, :status).count
    grouped.each_with_object({}) do |((campaign_id, status), count), acc|
      (acc[campaign_id] ||= {})[status] = count
    end
  end

  def campaign_json(campaign, status_counts)
    status_counts ||= {}

    {
      id: campaign.id,
      name: campaign.name,
      status: campaign.status,
      objective: campaign.objective,
      scheduled_for: campaign.scheduled_for,
      created_at: campaign.created_at,
      template_name: campaign.tracking_template&.name,
      inbox_name: campaign.inbox&.name,
      stats: aggregate_stats(status_counts)
    }
  end

  def aggregate_stats(status_counts)
    {
      total: status_counts.values.sum,
      pending: status_counts['pending'].to_i + status_counts['scheduled'].to_i,
      active: status_counts['active'].to_i + status_counts['paused'].to_i,
      completed: status_counts['completed'].to_i,
      failed: status_counts['failed'].to_i + status_counts['cancelled'].to_i
    }
  end
end
