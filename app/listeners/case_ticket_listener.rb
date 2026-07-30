# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Reapertura por respuesta del cliente (osTicket "Reopen on
# client reply"), paso 5 de [[Plan-Ticket-Cerrado]].
#
# Sin esto, el cliente contesta por WhatsApp/email sobre un caso ya cerrado y ese
# mensaje no llega a ningún lado del módulo: el ticket sigue cerrado y nadie se
# entera.
#
# ⚠️ El mensaje del propio agente también dispara MESSAGE_CREATED. Se filtra por
# `incoming?` o el ticket se reabriría al escribir la respuesta de cierre.
# ================================================================================

class CaseTicketListener < BaseListener
  REOPEN_REASON = 'El cliente respondió por su canal'

  def message_created(event)
    message, account = extract_message_and_account(event)
    return unless reopen_candidate?(message)

    ticket = closed_ticket_for(message)
    return if ticket.blank?
    return unless CaseSetting.for_account(account).reopen_on_customer_reply?

    if ticket.within_reopen_window?
      # actor: nil → el evento queda con origin :system, no atribuido a un agente.
      ticket.reopen!(actor: nil, reason: REOPEN_REASON)
    else
      # Fuera de la ventana no se resucita un caso de hace un año: se abre uno
      # nuevo enlazado al viejo, para no perder el hilo ni falsear las métricas.
      spawn_follow_up_ticket(ticket, message)
    end
  rescue StandardError => e
    # Un fallo aquí no puede tumbar la entrega del mensaje al cliente.
    Rails.logger.error("[CaseTicketListener] #{e.class}: #{e.message}")
  end

  private

  def reopen_candidate?(message)
    message.present? && message.incoming? && message.conversation_id.present?
  end

  # Un ticket puede haber sido reabierto y vuelto a cerrar; interesa el último.
  def closed_ticket_for(message)
    CaseTicket.where(conversation_id: message.conversation_id, status: :closed)
              .order(closed_at: :desc, id: :desc)
              .first
  end

  def spawn_follow_up_ticket(old_ticket, message)
    nuevo = build_follow_up(old_ticket, message)
    link_follow_up(old_ticket, nuevo)
    nuevo
  end

  def build_follow_up(old_ticket, message)
    old_ticket.account.case_tickets.create!(
      title:           "Seguimiento de #{old_ticket.folio || "##{old_ticket.id}"}: #{old_ticket.title}".truncate(255),
      description:     message.content.to_s.truncate(2000),
      contact_id:      old_ticket.contact_id,
      conversation_id: old_ticket.conversation_id,
      case_type_id:    old_ticket.case_type_id,
      priority:        old_ticket.priority,
      origin:          old_ticket.origin
    )
  end

  def link_follow_up(old_ticket, nuevo)
    CaseTicketRelation.create!(
      account:        old_ticket.account,
      ticket:         old_ticket,
      related_ticket: nuevo,
      relation_type:  :parent_child
    )

    nuevo.case_events.create!(
      account:    old_ticket.account,
      event_type: :related,
      origin:     :system,
      payload:    { reason: "Abierto por respuesta del cliente fuera del plazo de reapertura de #{old_ticket.folio}" }
    )
  end
end
