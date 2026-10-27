# frozen_string_literal: true

# prospeccion P2b — alguien del equipo escribió o movió la tarjeta en una conversación con
# un interesado entregado: si cuenta como atendido, la IA se calla ya (no a los 10 min).
# Se encola con unos segundos de espera desde Message y KanbanMove (ver HandoffAttention).
class TrackingCampaigns::HandoffAttendedJob < ApplicationJob
  queue_as :default

  DELAY = 20.seconds

  def perform(conversation_id)
    TrackingCampaigns::HandoffAttention.pending.where(conversation_id: conversation_id)
                                       .includes(:conversation, :tracking_campaign)
                                       .find_each { |tracking| TrackingCampaigns::HandoffAttention.check(tracking) }
  end
end
