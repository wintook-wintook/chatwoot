# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — A QUIÉN LE LLEGA CADA AVISO DE UNA LLAMADA
# ================================================================================
# El fork no tiene un canal ActionCable por cuenta (RoomChannel solo escucha el
# pubsub_token de cada usuario), y agregarlo filtraría llamadas a agentes de otras
# bandejas. Aquí se decide token por token.
#
#   voice_call.incoming          a quien debe sonar (ring_strategy de la bandeja):
#     cascade    asignado si está en línea → en línea de la bandeja → miembros + admins
#     all_online en línea de la bandeja → miembros + admins
#   accepted / ended             a todos a los que sonó (para quitar el timbre) + quien la tomó
#   outbound_connected/accepted  solo al agente que llamó
#   permission_granted           a quien pidió el permiso + el asignado
#
# A quién sonó se guarda en call.ring_state['ring_recipient_ids'] (no en meta: otra
# escritura de meta desde una copia vieja no lo borra).
# Plan: docs/llamadas_whatsapp_plan.md §4.2 y §4.3
# ================================================================================
class Calls::Broadcaster
  EVENT_PREFIX = 'voice_call.'

  pattr_initialize [:call!]

  # Hace sonar y anota a quiénes.
  def ring!(**extra)
    usuarios = ring_audience
    call.update_columns(ring_state: call.ring_state.merge('ring_recipient_ids' => usuarios.map(&:id))) # rubocop:disable Rails/SkipsModelValidations
    send_to(usuarios, :incoming, extra)
  end

  # accepted / ended / cualquier cambio que deba quitar el timbre o actualizar el widget.
  def to_ringers(event, **extra)
    ids = Array(call.ring_state['ring_recipient_ids']) | [call.accepted_by_agent_id].compact
    send_to(User.where(id: ids), event, extra)
  end

  # outbound_connected / outbound_accepted / ended de una saliente.
  def to_caller(event, **extra)
    send_to(User.where(id: call.accepted_by_agent_id), event, extra)
  end

  def self.permission_granted(conversation, requester_id:, **extra)
    ids = [requester_id, conversation.assignee_id].compact.uniq
    payload = { event: "#{EVENT_PREFIX}permission_granted",
                data: { account_id: conversation.account_id, conversation_id: conversation.display_id }.merge(extra) }
    User.where(id: ids).pluck(:pubsub_token).compact.each { |token| ActionCable.server.broadcast(token, payload) }
  end

  private

  def inbox
    call.inbox
  end

  def ring_audience
    online = online_inbox_agents
    if inbox.channel.try(:provider_config).to_h['ring_strategy'] != 'all_online'
      asignado = call.conversation.assignee
      return [asignado] if asignado && online.include?(asignado)
    end
    online.presence || inbox.assignable_agents
  end

  def online_inbox_agents
    disponibles = OnlineStatusTracker.get_available_users(inbox.account_id)
                                     .select { |_id, estado| estado.to_s == 'online' }.keys.map(&:to_i)
    inbox.assignable_agents.select { |usuario| disponibles.include?(usuario.id) }
  end

  def send_to(usuarios, event, extra)
    payload = { event: "#{EVENT_PREFIX}#{event}", data: base_data.merge(extra) }
    Array(usuarios).filter_map(&:pubsub_token).uniq.each { |token| ActionCable.server.broadcast(token, payload) }
  end

  def base_data
    { account_id: call.account_id, id: call.id, call_id: call.provider_call_id, provider: call.provider,
      conversation_id: call.conversation.display_id, inbox_id: call.inbox_id, direction: call.direction_label }
  end
end
