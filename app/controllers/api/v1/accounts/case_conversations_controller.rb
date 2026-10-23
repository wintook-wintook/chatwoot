# frozen_string_literal: true

# ================================================================================
# @tickets_cases — ligar una conversación a un caso que no tiene
# ================================================================================
# POST /api/v1/accounts/:id/case_tickets/:case_ticket_id/conversation
#        { conversation_id }  → liga una conversación del contacto (display_id)
#        { inbox_id }         → usa la conversación abierta del contacto en esa
#                               bandeja o crea una nueva ahí
#
# Un caso tiene una sola conversación y no se cambia: solo se liga si no tiene.
# Una conversación no puede tener dos casos abiertos de la misma clase (los
# agentes IA y el orquestador buscan el caso por conversación y clase).
# ================================================================================

class Api::V1::Accounts::CaseConversationsController < Api::V1::Accounts::BaseController
  REUSABLE_STATUSES = %w[open pending].freeze

  before_action :set_ticket

  def create
    conversation, created = params[:conversation_id].present? ? existing_conversation : inbox_conversation
    return if performed?
    return if clashing_case?(conversation)

    link!(conversation, created)
    render json: { conversation_display_id: conversation.display_id, inbox_id: conversation.inbox_id, created: created },
           status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
    return render_error('El caso ya tiene una conversación') if @ticket.conversation_id
    return render_error('Asigna un contacto al caso para ligar una conversación') unless @ticket.contact

    render_error('El caso está cerrado') if @ticket.frozen_for_edit?
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Caso no encontrado' }, status: :not_found
  end

  def existing_conversation
    conversation = @ticket.contact.conversations.find_by(account_id: Current.account.id,
                                                         display_id: params[:conversation_id])
    return render_error('Esa conversación no es del contacto del caso') unless conversation

    [conversation, false]
  end

  def inbox_conversation
    inbox = Current.user.assigned_inboxes.find_by(id: params[:inbox_id])
    return render_error('Elige una bandeja') unless inbox

    reusable = @ticket.contact.conversations.where(account_id: Current.account.id, inbox_id: inbox.id,
                                                   status: REUSABLE_STATUSES)
                      .order(last_activity_at: :desc).first
    return [reusable, false] if reusable

    [new_conversation(inbox), true]
  end

  def new_conversation(inbox)
    contact_inbox = ContactInboxBuilder.new(contact: @ticket.contact, inbox: inbox).perform
    ConversationBuilder.new(params: ActionController::Parameters.new({}), contact_inbox: contact_inbox).perform
  rescue ActionController::ParameterMissing
    render_error('Al contacto le falta el teléfono o el correo que pide esa bandeja')
  rescue StandardError
    render_error('No se puede crear una conversación en esa bandeja')
  end

  def clashing_case?(conversation)
    klass = @ticket.case_type&.case_class || 'support'
    other = Current.account.case_tickets.of_class(klass).where(conversation_id: conversation.id)
                   .where.not(status: CaseTicket::CLOSED_STATUSES).where.not(id: @ticket.id).first
    return false unless other

    render_error("Esa conversación ya tiene el caso #{other.folio} abierto")
    true
  end

  def link!(conversation, created)
    @ticket.update!(conversation: conversation)
    @ticket.case_events.create!(
      account: Current.account, event_type: :conversation_link, origin: :agent, actor: current_user,
      payload: { display_id: conversation.display_id, inbox_name: conversation.inbox&.name, created: created }
    )
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
