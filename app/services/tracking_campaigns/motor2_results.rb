# frozen_string_literal: true

# Campaña con Vendedor IA — el tablero de resultados (Motor2CampaignDetail):
#
#   funnel   audiencia → inscritos → enviados → entregados → leídos (WhatsApp) / clics (correo) → contestaron →
#            le interesó → pasó el relevo / cita → cotizaciones → ganadas
#   exits    no le interesa, pidió una persona, se dio de baja, falló el envío, omitidos y por qué
#   kind     invitar: confirmó / no va / sin respuesta · encuesta: contestaron, promedio, bajas y casos
#   money    cotizaciones y lo ganado de sus contactos desde que empezó
#   reasons  los últimos motivos de «no le interesa»
#
#   TrackingCampaigns::Motor2Results.new(campaign).call
#   TrackingCampaigns::Motor2Results.new(campaign).contacts(group) → [{ contact_id, name, … }] (los de un grupo)
class TrackingCampaigns::Motor2Results
  GROUPS = %w[replied interested relayed appointment not_interested no_reply not_read clicked confirmed declined low_score failed].freeze
  MAX_LIST = 500

  def initialize(campaign)
    @campaign = campaign
    @trackings = ContactTracking.where(tracking_campaign_id: campaign.id)
  end

  def call
    { funnel: funnel, exits: exits, kind: kind_results, money: money, reasons: reasons, list: list_summary,
      channel: @campaign.inbox&.whatsapp? ? 'whatsapp' : 'email' }
  end

  # Los contactos de un grupo del tablero (para verlos o armar otra campaña con ellos).
  def contacts(group)
    scope = group_scope(group.to_s)
    return [] unless scope

    scope.includes(:contact, :conversation).limit(MAX_LIST).map do |t|
      { contact_id: t.contact_id, name: t.contact&.name, phone_number: t.contact&.phone_number, email: t.contact&.email,
        conversation_id: t.conversation&.display_id, outcome: t.outcome, status: t.status }
    end
  end

  private

  # La lista fría subida, si hay: cuántos válidos, descartados por motivo, cuántos ya contestaron.
  def list_summary
    id = @campaign.audience.to_h.dig('source', 'list_id')
    ProspectList.find_by(id: id, account_id: @campaign.account_id)&.summary
  end

  def funnel
    { audience: @campaign.entries.count, enrolled: @campaign.entries.enrolled.count, sent: sent.count,
      delivered: delivered.count, read: read.count, clicked: clicked_contact_ids.size, replied: replied.count,
      interested: interested.count, relayed: relayed.count, appointment: appointment.count,
      quotes: quotes.count, won: quotes.won.count }
  end

  def exits
    { not_interested: @trackings.where(outcome: 'discarded').count, handed_off: @trackings.where(outcome: 'handed_off').count,
      opted_out: opted_out_count, failed: @trackings.where(status: 'failed').count, no_reply: no_reply.count,
      skipped: @campaign.entries.skipped.group(:reason).count }
  end

  def kind_results
    case @campaign.brief.to_h['kind']
    when 'invite' then invite_results
    when 'survey' then survey_results
    else {}
    end
  end

  def invite_results
    event = @campaign.event
    return {} unless event

    counts = event.attendees.where(contact_id: @trackings.select(:contact_id)).group(:status).count
    { event_name: event.name, capacity: event.capacity, confirmed: counts.fetch('confirmed', 0) + counts.fetch('attended', 0),
      declined: counts.fetch('cancelled', 0), attended: counts.fetch('attended', 0), invited: counts.values.sum }
  end

  def survey_results
    scores = []
    answered = 0
    @trackings.where("motor2_state ? 'survey'").pluck(:motor2_state).each do |state|
      values = state['survey'].to_h.values
      answered += 1 if values.any?
      scores.concat(values.filter_map { |v| v['calificacion'] }.map(&:to_f))
    end
    low = @campaign.brief.to_h['low_score'].to_i
    { answered: answered, average: scores.any? ? (scores.sum / scores.size).round(1) : nil,
      low: scores.count { |s| s < low }, cases: @trackings.where('outcome LIKE ?', 'Encuesta baja%').count }
  end

  def money
    { quoted_total: quotes.sum(:total).to_f, won_total: quotes.won.sum(:total).to_f, currency: quotes.pick(:currency) || 'MXN' }
  end

  def reasons
    @trackings.where(outcome: 'discarded').where("motor2_state ? 'exit_reason'").order(updated_at: :desc).limit(20)
              .pluck(Arel.sql("motor2_state->>'exit_reason'")).compact_blank
  end

  def sent = @trackings.where('attempt_count > 0')

  def deliveries(statuses) = TrackingDelivery.where(contact_tracking_id: @trackings.select(:id), status: statuses).select(:contact_tracking_id)

  def delivered
    return sent.where.not(status: 'failed') unless @campaign.inbox&.whatsapp?

    @trackings.where(id: deliveries(%w[delivered read]))
  end

  def read = @trackings.where(id: deliveries(%w[read]))

  def clicked_contact_ids = @campaign.clicks.distinct.pluck(:contact_id)

  # Contestó: tiene un mensaje del cliente en su conversación después de inscribirse.
  def replied
    @trackings.where('EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = contact_trackings.conversation_id ' \
                     'AND m.message_type = 0 AND m.created_at > contact_trackings.created_at)')
  end

  def no_reply = sent.where.not(id: replied.select(:id)).where(status: %w[completed cancelled failed scheduled active pending])

  def interested = @trackings.where("interested_at IS NOT NULL OR outcome LIKE 'relayed%'")

  def relayed = @trackings.where('outcome LIKE ?', 'relayed%')

  def appointment = @trackings.where("booked_at IS NOT NULL OR outcome LIKE 'Cita %'")

  def quotes
    @quotes ||= Quote.where(account_id: @campaign.account_id, contact_id: @trackings.select(:contact_id))
                     .where('created_at >= ?', @campaign.scheduled_for || @campaign.created_at)
  end

  def opted_out_count
    Contact.where(id: @trackings.select(:contact_id)).where('opted_out_at >= ?', @campaign.scheduled_for || @campaign.created_at).count
  end

  def group_scope(group)
    return nil unless GROUPS.include?(group)

    special = { 'not_interested' => -> { @trackings.where(outcome: 'discarded') },
                'not_read' => -> { sent.where.not(id: read.select(:id)) },
                'clicked' => -> { @trackings.where(contact_id: clicked_contact_ids) },
                'confirmed' => -> { attendee_scope(%w[confirmed attended]) }, 'declined' => -> { attendee_scope('cancelled') },
                'low_score' => -> { @trackings.where('outcome LIKE ?', 'Encuesta baja%') },
                'failed' => -> { @trackings.where(status: 'failed') } }
    special[group]&.call || send(group)
  end

  def attendee_scope(status)
    return @trackings.none unless @campaign.event

    @trackings.where(contact_id: @campaign.event.attendees.where(status: status).select(:contact_id))
  end
end
