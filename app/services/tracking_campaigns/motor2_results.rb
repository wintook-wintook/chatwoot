# frozen_string_literal: true

# Campaña con Vendedor IA — el tablero de resultados (Motor2CampaignDetail):
#
#   funnel   audiencia → inscritos → enviados → entregados → leídos (WhatsApp) / clics (correo) → contestaron →
#            le interesó → pasó el relevo / cita → cotizaciones → ganadas
#   touches  por toque: a cuántos les salió y cuántos contestaron después de ese toque
#   exits    no le interesa, pidió una persona, se dio de baja, rebotó, falló el envío, no contestó (ya sin toques),
#            en curso (aún con toques por salir), omitidos y por qué
#   Cotizaciones y ganadas: de los que contestaron, hechas desde que empezó y hasta ATTRIBUTION después del fin.
#   kind     invitar: confirmó / no va / sin respuesta · encuesta: contestaron, promedio, bajas y casos
#   money    cotizaciones y lo ganado de sus contactos desde que empezó
#   reasons  los últimos motivos de «no le interesa»
#
#   TrackingCampaigns::Motor2Results.new(campaign).call
#   TrackingCampaigns::Motor2Results.new(campaign).contacts(group) → [{ contact_id, name, … }] (los de un grupo)
class TrackingCampaigns::Motor2Results
  GROUPS = %w[replied interested relayed appointment not_interested no_reply in_progress not_read clicked confirmed declined low_score
              failed bounced achieved not_now future_yes].freeze
  MAX_LIST = 500
  ATTRIBUTION = 30.days
  FINISHED = %w[completed cancelled].freeze
  WAITING = %w[pending scheduled active paused].freeze

  def initialize(campaign)
    @campaign = campaign
    @trackings = ContactTracking.where(tracking_campaign_id: campaign.id)
  end

  def call
    { funnel: funnel, touches: touches, exits: exits, kind: kind_results, money: money, reasons: reasons, list: list_summary,
      goal: goal_results,
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

  # Todos los contactos de un grupo (para «Otra campaña con…»; sin el tope de MAX_LIST de la lista en pantalla).
  def contact_ids(group)
    scope = group_scope(group.to_s)
    scope ? scope.distinct.limit(ContactTrackings::BulkAssignService::MAX_BULK_ASSIGN).pluck(:contact_id) : []
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
      opted_out: opted_out_count, bounced: bounced.count, failed: @trackings.where(status: 'failed').count, no_reply: no_reply.count,
      in_progress: in_progress.count, skipped: @campaign.entries.skipped.group(:reason).count }
  end

  # Por toque (Motor2::CampaignSendHook anota motor2_state.touches_sent y Motor2::Reply replied_on_touch).
  def touches
    attempts = @campaign.touches.to_h['attempts'].to_i.clamp(1, TrackingCampaigns::Motor2Brief::MAX_TOUCHES)
    sent_by = @trackings.where("motor2_state ? 'touches_sent'").group(Arel.sql("(motor2_state->>'touches_sent')::int")).count
    replied_by = @trackings.where("motor2_state ? 'replied_on_touch'").group(Arel.sql("(motor2_state->>'replied_on_touch')::int")).count
    (1..attempts).map do |n|
      { n: n, sent: sent_by.sum { |k, v| k.to_i >= n ? v : 0 }, replied: replied_by.fetch(n, 0) }
    end
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

  # Encuesta: contestaron, promedio, bajas, casos, NPS y comentarios (TrackingCampaigns::SurveyResults).
  def survey_results = TrackingCampaigns::SurveyResults.new(@campaign, @trackings).call

  # El objetivo de la campaña (TrackingCampaigns::CampaignKit): lo lograron, «no esta vez», aceptan la próxima, no quieren.
  def goal_results
    brief = @campaign.brief.to_h
    { goal: brief['offer_goal'], achieved: achieved.count, not_now: @trackings.where(outcome: 'not_now').count,
      future_yes: @trackings.where(outcome: 'future_yes').count, opt_out: @trackings.where(outcome: 'discarded').count,
      labels: TrackingCampaigns::CampaignKit::LABEL_KEYS.index_with { |k| TrackingCampaigns::CampaignKit.label(brief, k).presence } }
  end

  def achieved = @trackings.where('outcome LIKE ?', 'Logrado:%')

  def not_now = @trackings.where(outcome: %w[not_now])

  def future_yes = @trackings.where(outcome: 'future_yes')

  def money
    { quoted_total: quotes.sum(:total).to_f, won_total: quotes.won.sum(:total).to_f, currency: quotes.pick(:currency) || 'MXN' }
  end

  def reasons
    @trackings.where(outcome: 'discarded').where("motor2_state ? 'exit_reason'").order(updated_at: :desc).limit(20)
              .pluck(Arel.sql("motor2_state->>'exit_reason'")).compact_blank
  end

  # Ya le salió al menos un toque (attempt_count lo reinicia el seguimiento corto; last_attempt_at no).
  def sent = @trackings.where('contact_trackings.attempt_count > 0 OR contact_trackings.last_attempt_at IS NOT NULL')

  def bounced = @trackings.where(prospect_exit: 'bounced')

  def deliveries(statuses) = TrackingDelivery.where(contact_tracking_id: @trackings.select(:id), status: statuses).select(:contact_tracking_id)

  def delivered
    return sent.where.not(status: 'failed').where('prospect_exit IS DISTINCT FROM ?', 'bounced') unless @campaign.inbox&.whatsapp?

    @trackings.where(id: deliveries(%w[delivered read]))
  end

  def read = @trackings.where(id: deliveries(%w[read]))

  def clicked_contact_ids = @campaign.clicks.distinct.pluck(:contact_id)

  # Contestó: tiene un mensaje del cliente en su conversación después de inscribirse.
  def replied
    @trackings.where('EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = contact_trackings.conversation_id ' \
                     'AND m.message_type = 0 AND m.created_at > contact_trackings.created_at)')
  end

  # No contestó y ya no le sale nada (terminó sus toques); los que aún esperan toques van en «en curso».
  def no_reply
    sent.where.not(id: replied.select(:id)).where(status: FINISHED, prospect_exit: nil)
        .where("contact_trackings.outcome IS NULL OR contact_trackings.outcome NOT IN ('discarded', 'opted_out')")
  end

  def in_progress = @trackings.where.not(id: replied.select(:id)).where(status: WAITING)

  def interested = @trackings.where("interested_at IS NOT NULL OR outcome LIKE 'relayed%'")

  def relayed = @trackings.where('outcome LIKE ?', 'relayed%')

  def appointment = @trackings.where("booked_at IS NOT NULL OR outcome LIKE 'Cita %'")

  # Atribución: solo de los que contestaron, y hasta ATTRIBUTION después del fin (o de hoy, si sigue).
  def quotes
    start = @campaign.scheduled_for || @campaign.created_at
    finish = (@campaign.ends_at && @campaign.ends_at < Time.current ? @campaign.ends_at : Time.current) + ATTRIBUTION
    @quotes ||= Quote.where(account_id: @campaign.account_id, contact_id: replied.select(:contact_id))
                     .where(created_at: start..finish)
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
                'failed' => -> { @trackings.where(status: 'failed') }, 'bounced' => -> { bounced } }
    special[group]&.call || send(group)
  end

  def attendee_scope(status)
    return @trackings.none unless @campaign.event

    @trackings.where(contact_id: @campaign.event.attendees.where(status: status).select(:contact_id))
  end
end
