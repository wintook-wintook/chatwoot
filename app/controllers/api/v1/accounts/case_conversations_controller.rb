# frozen_string_literal: true

# ================================================================================
# @tickets_cases — conversaciones de un caso
# ================================================================================
# POST /api/v1/accounts/:id/case_tickets/:case_ticket_id/conversation
#        { conversation_id }  → liga una conversación del contacto (display_id)
#        { inbox_id }         → usa la conversación abierta del contacto en esa
#                               bandeja o crea una nueva ahí
# GET    …/case_tickets/:case_ticket_id/conversations      → ligadas y sin ligar
# DELETE …/case_tickets/:case_ticket_id/conversations/:id  → quita una adicional
#
# La primera que se liga es la PRINCIPAL (case_tickets.conversation_id): es a la
# que se responde y la que reabre el caso, y no se cambia. Plan Actividad del
# caso — las siguientes quedan como ADICIONALES (p. ej. el hilo de correo): solo
# se leen para la actividad del caso.
# Una conversación no puede ser principal de dos casos abiertos de la misma clase
# (los agentes IA y el orquestador buscan el caso por conversación y clase).
# ================================================================================

class Api::V1::Accounts::CaseConversationsController < Api::V1::Accounts::BaseController
  REUSABLE_STATUSES = %w[open pending].freeze

  before_action :set_ticket
  before_action :check_editable, only: %i[create destroy]

  def index
    linked = @ticket.linked_conversations
    others = @ticket.contact ? contact_conversations.where.not(id: linked.map(&:id)).order(last_activity_at: :desc) : []
    render json: { conversations: linked.map { |c| conversation_json(c) }, unlinked: others.map { |c| conversation_json(c) } }
  end

  def create
    conversation, created = params[:conversation_id].present? ? existing_conversation : inbox_conversation
    return if performed?

    if @ticket.conversation_id
      link_extra!(conversation, created)
    else
      return if clashing_case?(conversation)

      link!(conversation, created)
    end
    render json: { conversation_display_id: conversation.display_id, inbox_id: conversation.inbox_id, created: created,
                   primary: @ticket.conversation_id == conversation.id },
           status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  end

  def destroy
    link = @ticket.extra_conversation_links.joins(:conversation).find_by(conversations: { display_id: params[:id] })
    return render_error('Solo se pueden quitar las conversaciones adicionales') unless link

    link.destroy!
    log!(:conversation_unlinked, link.conversation)
    head :ok
  end

  private

  def set_ticket
    @ticket = account_case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Caso no encontrado' }, status: :not_found
  end

  def check_editable
    return render_error('Asigna un contacto al caso para ligar una conversación') unless @ticket.contact

    render_error('El caso está cerrado') if @ticket.frozen_for_edit?
  end

  def contact_conversations
    @ticket.contact.conversations.where(account_id: Current.account.id).includes(:inbox)
  end

  def existing_conversation
    conversation = contact_conversations.find_by(display_id: params[:conversation_id])
    return render_error('Esa conversación no es del contacto del caso') unless conversation

    [conversation, false]
  end

  def inbox_conversation
    inbox = Current.user.assigned_inboxes.find_by(id: params[:inbox_id])
    return render_error('Elige una bandeja') unless inbox

    reusable = contact_conversations.where(inbox_id: inbox.id, status: REUSABLE_STATUSES)
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
    @ticket.extra_conversation_links.where(conversation: conversation).destroy_all
    log!(:conversation_link, conversation, created: created)
  end

  def link_extra!(conversation, created)
    @ticket.extra_conversation_links.create!(account: Current.account, conversation: conversation, linked_by: current_user)
    log!(:conversation_link, conversation, created: created, extra: true)
  end

  def log!(type, conversation, **extra)
    @ticket.case_events.create!(
      account: Current.account, event_type: type, origin: :agent, actor: current_user,
      payload: { display_id: conversation.display_id, inbox_name: conversation.inbox&.name }.merge(extra)
    )
  end

  def conversation_json(conversation)
    { display_id: conversation.display_id, primary: conversation.id == @ticket.conversation_id,
      inbox_id: conversation.inbox_id, inbox_name: conversation.inbox&.name,
      channel_type: conversation.inbox&.channel_type, status: conversation.status,
      last_activity_at: conversation.last_activity_at }
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
