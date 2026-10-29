# frozen_string_literal: true

# ================================================================================
# prospeccion P2b — EL VENDEDOR ENTRÓ: LA IA SE CALLA (§10.9)
# ================================================================================
# «Atendido» = después de la entrega, una persona del equipo le escribió al cliente
# (saliente público de un User, sin marcas de bot —la regla de ConversationEvidence— y
# que no sea un toque del seguimiento) o movió la tarjeta a mano a otra columna.
#
# Al atender: handoff_attended_at, el seguimiento pasa a «objetivo cumplido» (cancela sus
# toques) y queda nota de actividad. Desde ahí la conversación es del vendedor:
# ContactTrackingResponseAnalyzerJob no contesta ni escala a BotSeller (seller_owns?).
#
# Lo revisan HandoffAttendedJob (unos segundos después del mensaje o del movimiento: la
# marca de bot se guarda justo DESPUÉS de crear el mensaje) y HandoffSweepJob (cada 10 min).
# ================================================================================
module TrackingCampaigns::HandoffAttention
  BOT_MARKS = ContactTrackings::Assistant::ConversationEvidence::BOT_MARKS

  module_function

  def pending
    ContactTracking.where.not(handed_off_at: nil).where(handoff_attended_at: nil).where.not(conversation_id: nil)
  end

  def pending?(conversation_id)
    pending.exists?(conversation_id: conversation_id)
  end

  def seller_owns?(conversation)
    ContactTracking.where(conversation_id: conversation.id).where.not(handoff_attended_at: nil).exists?
  end

  # true si ya lo atendieron (y se marcó).
  def check(tracking)
    at = attended_at(tracking)
    return false unless at

    tracking.update_columns(handoff_attended_at: at) # rubocop:disable Rails/SkipsModelValidations
    tracking.mark_objective_met!
    note(tracking)
    true
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

  def note(tracking)
    conversation = tracking.conversation
    seller = conversation.assignee&.name || I18n.t('tracking_campaigns.hand_off.someone')
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: I18n.t('tracking_campaigns.hand_off.attended', seller: seller))
  end
end
