# frozen_string_literal: true

# ================================================================================
# prospeccion P2 — ENTREGAR AL INTERESADO (§10.9)
# ================================================================================
# Lo usan el botón «Entregar» (V6, con el usuario) y el clasificador (V5) cuando el
# prospecto dice que le interesa y la campaña tiene tablero de entrega (auto_handoff?).
#
#   1. la conversación entra al tablero/columna de Oportunidades de la campaña
#      (Kanban::FunnelMover#move!, con su nota de actividad), si la campaña los tiene
#   2. vendedor = el asignado de la conversación; si no hay, quien creó la campaña
#      (y se le asigna)
#   3. reloj: vence = ahora + plazo; escala = ahora + escalar (horas hábiles, BusinessClock)
#   4. nota privada con @mención al vendedor → notificación de Chatwoot
#
# Solo entrega a un «interesado»; si ya estaba entregado no hace nada.
# ================================================================================
class TrackingCampaigns::HandOff
  def initialize(tracking, user: nil)
    @tracking = tracking
    @campaign = tracking.tracking_campaign
    @conversation = tracking.conversation
    @user = user
  end

  # true si lo entregó.
  def call
    return false unless @tracking.prospect_stage == 'interested'

    now = Time.current
    move_to_board
    seller = assign_seller
    @tracking.update!(prospect_stage: 'handed_off', handed_off_at: now, **clock(now))
    notify(seller)
    true
  end

  def self.mention(user)
    "[@#{user.name}](mention://user/#{user.id}/#{ERB::Util.url_encode(user.name)})"
  end

  private

  def move_to_board
    return unless @conversation && @campaign&.auto_handoff?

    Kanban::FunnelMover.new(@conversation).move!(
      @campaign.handoff_board, @campaign.handoff_column,
      source: @user ? 'manual' : 'automation', user_id: @user&.id,
      reason: I18n.t('tracking_campaigns.hand_off.board_reason', campaign: @campaign.name)
    )
  end

  def assign_seller
    return if @conversation.nil?
    return @conversation.assignee if @conversation.assignee

    seller = @campaign&.user
    @conversation.update!(assignee: seller) if seller
    seller
  end

  def clock(now)
    business = TrackingCampaigns::BusinessClock.new(@tracking.inbox)
    { handoff_due_at: business.add(now, @campaign&.handoff_due_hours),
      handoff_escalate_at: business.add(now, @campaign&.handoff_escalate_hours) }
  end

  def notify(seller)
    return if @conversation.nil?

    @conversation.messages.create!(account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                                   message_type: :outgoing, private: true, sender: @user, content: note(seller))
  end

  def note(seller)
    who = seller ? "#{self.class.mention(seller)} " : ''
    due = @tracking.handoff_due_at
    deadline = due ? I18n.t('tracking_campaigns.hand_off.deadline', at: I18n.l(due.in_time_zone(zone), format: :short)) : ''
    "🎯 #{who}#{I18n.t('tracking_campaigns.hand_off.note', campaign: @campaign&.name)}#{deadline}"
  end

  def zone
    @tracking.inbox&.timezone.presence || 'UTC'
  end
end
