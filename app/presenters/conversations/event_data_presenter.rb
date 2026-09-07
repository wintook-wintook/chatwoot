class Conversations::EventDataPresenter < SimpleDelegator
  def push_data
    {
      additional_attributes: additional_attributes,
      can_reply: can_reply?,
      channel: inbox.try(:channel_type),
      contact_inbox: contact_inbox,
      id: display_id,
      inbox_id: inbox_id,
      messages: push_messages,
      labels: label_list,
      meta: push_meta,
      status: status,
      custom_attributes: custom_attributes,
      snoozed_until: snoozed_until,
      unread_count: unread_incoming_messages.count,
      first_reply_created_at: first_reply_created_at,
      priority: priority,
      waiting_since: waiting_since.to_i,
      **push_timestamps
    }
  end

  # CAMBIO LOCAL (no upstream): los eventos de conversacion salian sin ninguna referencia
  # a la cuenta -- ni `account` anidado como en los de mensaje/contacto, ni el id -- asi
  # que con `instance_url` sola el receptor seguia sin poder armar el enlace
  # <instance_url>/app/accounts/<account_id>/conversations/<id>.
  #
  # Va aqui y NO en push_data porque push_data alimenta tambien el websocket del
  # dashboard: agregarlo alli cambiaria el payload que reciben todos los agentes.
  # Se manda el id y no `account.webhook_data` para no pagar una consulta por evento:
  # account_id es columna de conversations.
  def webhook_data
    push_data.merge(account_id: account_id)
  end

  private

  def push_messages
    [messages.chat.last&.push_event_data].compact
  end

  def push_meta
    {
      sender: contact.push_event_data,
      assignee: assignee&.push_event_data,
      team: team&.push_event_data,
      hmac_verified: contact_inbox&.hmac_verified
    }
  end

  def push_timestamps
    {
      agent_last_seen_at: agent_last_seen_at.to_i,
      contact_last_seen_at: contact_last_seen_at.to_i,
      last_activity_at: last_activity_at.to_i,
      timestamp: last_activity_at.to_i,
      created_at: created_at.to_i
    }
  end
end
Conversations::EventDataPresenter.prepend_mod_with('Conversations::EventDataPresenter')
