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
  # Intenciones que cuentan como "interesado" en el embudo (igual que el overview de cuenta).
  INTERESTED_INTENTS = %w[interested book_appointment reschedule].freeze

  def index
    campaigns = Current.account.tracking_campaigns
                       .includes(:tracking_template, :inbox)
                       .order(created_at: :desc)
    ids = campaigns.map(&:id)
    stats = stats_by_campaign(ids)
    delivery = delivery_by_campaign(ids)
    funnel = funnel_by_campaign(ids)

    render json: campaigns.map { |campaign| campaign_json(campaign, stats[campaign.id], delivery[campaign.id], funnel[campaign.id]) }
  end

  def show
    campaign = Current.account.tracking_campaigns.find(params[:id])
    stats = stats_by_campaign([campaign.id])
    delivery = delivery_by_campaign([campaign.id])
    funnel = funnel_by_campaign([campaign.id])

    render json: campaign_json(campaign, stats[campaign.id], delivery[campaign.id], funnel[campaign.id])
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

  # Eje de ENTREGA (WhatsApp), separado del de ejecución ([[Entrega-vs-ejecucion]]).
  # Unidad = estado del ÚLTIMO mensaje saliente por conversación (1 por prospecto),
  # NO mensajes crudos. Devuelve { campaign_id => { delivered:, sent:, failed: } }.
  def delivery_by_campaign(ids)
    return {} if ids.blank?

    # conversation_id => campaign_id (solo prospectos que ya tienen conversación)
    conv_to_campaign = ContactTracking.where(tracking_campaign_id: ids)
                                      .where.not(conversation_id: nil)
                                      .pluck(:conversation_id, :tracking_campaign_id)
                                      .to_h
    return {} if conv_to_campaign.empty?

    last_outgoing_messages(conv_to_campaign.keys).each_with_object({}) do |message, acc|
      campaign_id = conv_to_campaign[message.conversation_id]
      bucket = delivery_bucket(message.status)
      (acc[campaign_id] ||= Hash.new(0))[bucket] += 1
    end
  end

  # Último mensaje saliente (outgoing/template) por conversación, en 2 queries (sin N+1).
  def last_outgoing_messages(conversation_ids)
    # reorder(nil): Message tiene default_scope con ORDER BY que rompe el GROUP BY.
    last_ids = Message.where(conversation_id: conversation_ids, message_type: %i[outgoing template])
                      .reorder(nil).group(:conversation_id).maximum(:id)
    return [] if last_ids.empty?

    Message.where(id: last_ids.values).select(:id, :conversation_id, :status)
  end

  # Message.status (string del enum) → bucket de entrega. read cuenta como entregado;
  # sent/progress = enviado sin confirmar; failed = rechazado por el canal.
  def delivery_bucket(status)
    case status
    when 'delivered', 'read' then :delivered
    when 'failed'            then :failed
    else                          :sent
    end
  end

  # Embudo de intención por campaña (respondieron/interesados/agendaron), mismo
  # criterio que el overview de cuenta: replied = last_intent no nulo. 3 queries
  # agregadas (sin N+1). Devuelve { campaign_id => { replied:, interested:, appointment: } }.
  def funnel_by_campaign(ids)
    return {} if ids.blank?

    base = ContactTracking.where(tracking_campaign_id: ids)
    replied = base.where.not(last_intent: nil).group(:tracking_campaign_id).count
    interested = base.where(last_intent: INTERESTED_INTENTS).group(:tracking_campaign_id).count
    appointment = base.where.not(appointment_at: nil).group(:tracking_campaign_id).count

    ids.index_with do |id|
      { replied: replied[id].to_i, interested: interested[id].to_i, appointment: appointment[id].to_i }
    end
  end

  def campaign_json(campaign, status_counts, delivery_counts, funnel_counts)
    {
      id: campaign.id,
      name: campaign.name,
      status: campaign.status,
      objective: campaign.objective,
      scheduled_for: campaign.scheduled_for,
      created_at: campaign.created_at,
      template_name: campaign.tracking_template&.name,
      inbox_name: campaign.inbox&.name,
      stats: aggregate_stats(status_counts || {}),
      delivery: aggregate_delivery(delivery_counts || {}),
      funnel: funnel_counts || { replied: 0, interested: 0, appointment: 0 }
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

  def aggregate_delivery(delivery_counts)
    {
      delivered: delivery_counts[:delivered].to_i,
      sent: delivery_counts[:sent].to_i,
      failed: delivery_counts[:failed].to_i
    }
  end
end
