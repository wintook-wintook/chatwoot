# frozen_string_literal: true

# ================================================================================
# prospeccion P2 — ¿YA ATENDIERON AL INTERESADO? (§10.9) · cada 10 min (schedule.yml)
# ================================================================================
# Para cada entregado sin atender (de los últimos LOOKBACK días):
#
#   ¿lo atendió?  una persona del equipo le escribió al cliente después de la entrega
#                 (saliente público de un User, sin marcas de bot —la misma regla que
#                 ConversationEvidence— y que no sea un toque del seguimiento), o alguien
#                 movió la tarjeta a mano a otra columna de Oportunidades
#     sí               → handoff_attended_at (se para el reloj)
#     venció el plazo  → nota «⏰» con @mención al vendedor (una vez)
#     venció escalar   → nota «🚨» con @mención a los administradores (una vez)
# ================================================================================
class TrackingCampaigns::HandoffSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  LOOKBACK = 30.days
  BOT_MARKS = ContactTrackings::Assistant::ConversationEvidence::BOT_MARKS

  def perform(now = Time.current)
    pending.find_each do |tracking|
      sweep(tracking, now)
    rescue StandardError => e
      Rails.logger.error("[HandoffSweep] tracking ##{tracking.id}: #{e.message}")
    end
  end

  private

  def pending
    ContactTracking.where(handoff_attended_at: nil).where(handed_off_at: LOOKBACK.ago..)
                   .where.not(conversation_id: nil).includes(:conversation, :tracking_campaign)
  end

  def sweep(tracking, now)
    attended = attended_at(tracking)
    return tracking.update_columns(handoff_attended_at: attended) if attended # rubocop:disable Rails/SkipsModelValidations

    remind(tracking, now) if due?(tracking.handoff_due_at, tracking.handoff_reminded_at, now)
    escalate(tracking, now) if due?(tracking.handoff_escalate_at, tracking.handoff_escalated_at, now)
  end

  def due?(deadline, done, now)
    deadline.present? && done.nil? && deadline <= now
  end

  def attended_at(tracking)
    [first_human_message(tracking), first_manual_move(tracking)].compact.min
  end

  def first_human_message(tracking)
    touches = TrackingDelivery.where(contact_tracking_id: tracking.id).where.not(message_id: nil).select(:message_id)
    tracking.conversation.messages.outgoing.where(private: false, sender_type: 'User')
            .where('messages.created_at > ?', tracking.handed_off_at).where.not(id: touches).order(:created_at)
            .detect { |message| !message.content_attributes.to_h.keys.map(&:to_s).intersect?(BOT_MARKS) }&.created_at
  end

  # La entrega misma mueve la tarjeta a la columna de entrega: esa no cuenta.
  def first_manual_move(tracking)
    KanbanMove.where(conversation_id: tracking.conversation_id, source: 'manual').where.not(user_id: nil)
              .where('created_at > ?', tracking.handed_off_at)
              .where.not(to_process_id: tracking.tracking_campaign&.handoff_column_id)
              .minimum(:created_at)
  end

  def remind(tracking, now)
    seller = tracking.conversation.assignee
    note(tracking, I18n.t('tracking_campaigns.hand_off.reminder', who: mentions([seller].compact), campaign: campaign_name(tracking)))
    tracking.update_columns(handoff_reminded_at: now) # rubocop:disable Rails/SkipsModelValidations
  end

  def escalate(tracking, now)
    since = I18n.l(tracking.handed_off_at.in_time_zone(zone(tracking)), format: :short)
    note(tracking, I18n.t('tracking_campaigns.hand_off.escalation', who: mentions(tracking.account.administrators),
                                                                    campaign: campaign_name(tracking), since: since))
    tracking.update_columns(handoff_escalated_at: now) # rubocop:disable Rails/SkipsModelValidations
  end

  def note(tracking, content)
    conversation = tracking.conversation
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                  message_type: :outgoing, private: true, content: content)
  end

  def mentions(users)
    users.map { |user| "#{TrackingCampaigns::HandOff.mention(user)} " }.join
  end

  def campaign_name(tracking)
    tracking.tracking_campaign&.name
  end

  def zone(tracking)
    tracking.inbox&.timezone.presence || 'UTC'
  end
end
