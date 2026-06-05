# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Servicio: Cases::TicketCreatorService
# Responsabilidad: Detecta la directiva @crear_ticket en complementary_prompt
#                  y crea un CaseTicket cuando KnowledgeBaseResponseService
#                  no pudo resolver la consulta.
#
# Retorna true si creó el ticket y respondió al cliente, false si no actuó.
#
# Posición en el flujo del job:
#   [1] KnowledgeBaseResponseService  → si resuelve: fin
#   [2] Cases::TicketCreatorService   → si @crear_ticket: crea ticket + confirma al cliente
#   [3] generate_and_send_conversational_reply (fallback)
# ================================================================================

class Cases::TicketCreatorService
  DIRECTIVE = '@crear_ticket'

  def initialize(message, tracking:)
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @conversation = message.conversation
    @contact      = message.conversation.contact
  end

  def create_if_needed
    return false unless directive_present?

    ticket = Cases::OrchestratorService.new(
      account:      @account,
      contact:      @contact,
      conversation: @conversation
    ).find_or_create_from_message(@message, tracking: @tracking)

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!

    send_confirmation(ticket)
    true
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error creando ticket: #{e.message}"
    false
  end

  private

  def directive_present?
    @tracking&.complementary_prompt.to_s.include?(DIRECTIVE)
  end

  def send_confirmation(ticket)
    text = "Tu consulta fue registrada (caso ##{ticket.id}). " \
           'Un asesor te contactará a la brevedad.'

    reply = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      { content: text, private: false }
    ).perform

    if reply.present?
      reply.content_attributes[:ticket_created] = true
      reply.save!
    end

    ticket.case_events.create!(
      account:    @account,
      event_type: :message_sent,
      origin:     :bot,
      payload:    { content: text, ticket_id: ticket.id }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación: #{e.message}"
  end

  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end
end
