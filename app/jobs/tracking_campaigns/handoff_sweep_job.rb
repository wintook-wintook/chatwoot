# frozen_string_literal: true

# ================================================================================
# prospeccion P2 — ¿YA ATENDIERON AL INTERESADO? (§10.9) · cada 10 min (schedule.yml)
# ================================================================================
# Para cada entregado sin atender (de los últimos LOOKBACK días):
#
#   ¿lo atendió?  (TrackingCampaigns::HandoffAttention — la red de seguridad de
#                 HandoffAttendedJob, que lo revisa al momento)
#     sí               → atendido: se para el reloj y la IA se calla
#     venció el plazo  → nota «⏰» con @mención al vendedor (una vez)
#     venció escalar   → nota «🚨» con @mención a los administradores (una vez)
# ================================================================================
class TrackingCampaigns::HandoffSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  LOOKBACK = 30.days

  def perform(now = Time.current)
    pending.find_each do |tracking|
      sweep(tracking, now)
    rescue StandardError => e
      Rails.logger.error("[HandoffSweep] tracking ##{tracking.id}: #{e.message}")
    end
  end

  private

  def pending
    TrackingCampaigns::HandoffAttention.pending.where(handed_off_at: LOOKBACK.ago..).includes(:conversation, :tracking_campaign)
  end

  def sweep(tracking, now)
    return if TrackingCampaigns::HandoffAttention.check(tracking)

    remind(tracking, now) if due?(tracking.handoff_due_at, tracking.handoff_reminded_at, now)
    escalate(tracking, now) if due?(tracking.handoff_escalate_at, tracking.handoff_escalated_at, now)
  end

  def due?(deadline, done, now)
    deadline.present? && done.nil? && deadline <= now
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
