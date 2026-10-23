# frozen_string_literal: true

# ================================================================================
# @campanas_vendedor — Eje de ENTREGA (WhatsApp) de las campañas
# ================================================================================
# Separado del de ejecución ([[Entrega-vs-ejecucion]]). Unidad = 1 por prospecto
# (seguimiento), NO mensajes crudos.
#
# proyecto@automatizacion_campanas (Fase 1): el estado sale del ÚLTIMO envío registrado del
# seguimiento (TrackingDelivery, ver TrackingDelivery.bucket). Los seguimientos sin envíos
# registrados (de antes de la Fase 1) siguen usando el último mensaje saliente de su
# conversación. Los fallidos se desglosan por motivo de Meta.
#
# Uso: TrackingCampaigns::DeliveryStats.new(campaign_ids).call
#   # => { campaign_id => { delivered:, sent:, unconfirmed:, retrying:, failed:, failure_reasons: } }
# ================================================================================
class TrackingCampaigns::DeliveryStats
  TOP_REASONS = 5

  def initialize(campaign_ids)
    @campaign_ids = campaign_ids
    @counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @reasons = Hash.new { |hash, key| hash[key] = Hash.new(0) }
  end

  def call
    return {} if @campaign_ids.blank?

    covered = recorded_deliveries.map { |row| count_recorded(row) }
    count_legacy(covered)
    @reasons.each { |campaign_id, by_reason| @counts[campaign_id][:failure_reasons] = top_reasons(by_reason) }
    @counts
  end

  private

  def recorded_deliveries
    latest_ids = TrackingDelivery.where(tracking_campaign_id: @campaign_ids).group(:contact_tracking_id).select('MAX(id)')
    TrackingDelivery.where(id: latest_ids)
                    .select(:tracking_campaign_id, :contact_tracking_id, :status, :next_retry_at, :error_code, :error_title)
  end

  # Cuenta el envío en su grupo y devuelve su seguimiento (ya no cuenta por mensaje).
  def count_recorded(delivery)
    bucket = delivery.bucket.to_sym
    @counts[delivery.tracking_campaign_id][bucket] += 1
    @reasons[delivery.tracking_campaign_id][[delivery.error_code, delivery.error_title]] += 1 if bucket == :failed
    delivery.contact_tracking_id
  end

  # [{ code:, title:, count: }] de los motivos más comunes
  def top_reasons(by_reason)
    by_reason.sort_by { |_, count| -count }.first(TOP_REASONS).map { |(code, title), count| { code: code, title: title, count: count } }
  end

  def count_legacy(covered_tracking_ids)
    # conversation_id => campaign_id (solo prospectos que ya tienen conversación)
    conv_to_campaign = ContactTracking.where(tracking_campaign_id: @campaign_ids)
                                      .where.not(conversation_id: nil)
                                      .where.not(id: covered_tracking_ids)
                                      .pluck(:conversation_id, :tracking_campaign_id)
                                      .to_h
    return if conv_to_campaign.empty?

    last_outgoing_messages(conv_to_campaign.keys).each do |message|
      @counts[conv_to_campaign[message.conversation_id]][TrackingDelivery.bucket(message.status).to_sym] += 1
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
end
