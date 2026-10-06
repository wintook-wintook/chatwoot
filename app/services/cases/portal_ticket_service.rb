# frozen_string_literal: true

# ================================================================================
# @tickets_cases — User Portal (P1)
# ================================================================================
# Servicio: Cases::PortalTicketService
# Responsabilidad: orquestar la apertura de un ticket desde el portal público.
#
#   [A] find_or_create contacto  (por email o teléfono — guest, sin login)
#   [B] resolver conversación    (reusar una abierta del contacto, o crear en
#                                 el inbox "Portal" del propio portal)
#   [C] crear ticket             (origin: web, folio automático)
#   [D] sembrar el hilo          (Cases::PortalThreadSeeder: nota privada + acuse)
#
# Devuelve el CaseTicket creado (con folio para el acuse al cliente).
# ================================================================================

class Cases::PortalTicketService
  # Conversaciones consideradas "abiertas" para reusar el hilo del contacto.
  REUSABLE_STATUSES = %w[open pending].freeze

  def initialize(portal:, name:, subject:, message:, email: nil, phone: nil,
                 case_type_id: nil, custom_attributes: {}, attachments: nil)
    @portal            = portal
    @account           = portal.account
    @name              = name
    @subject           = subject.to_s.strip
    @message           = message.to_s.strip
    @email             = email.presence
    @phone             = phone.presence
    @case_type_id      = case_type_id
    @custom_attributes = custom_attributes || {}
    @attachments       = attachments.presence
  end

  def perform
    inbox = @portal.ensure_inbox!
    validate_identifier!(inbox)
    contact_inbox = build_contact_inbox(inbox)
    contact       = contact_inbox.contact
    conversation, is_new = resolve_conversation(contact, contact_inbox)

    ticket = Cases::OrchestratorService.new(
      account: @account, contact: contact, conversation: conversation
    ).create_from_portal(
      title:             ticket_title,
      case_type_id:      resolved_case_type_id,
      description:       @message,
      custom_attributes: @custom_attributes
    )

    Cases::PortalThreadSeeder.new(
      conversation: conversation, ticket: ticket, body: @message,
      new_conversation: is_new, attachments: @attachments, portal: @portal
    ).perform

    ticket
  end

  private

  # El canal del inbox destino exige cierto identificador (Email→correo, WhatsApp→móvil).
  def validate_identifier!(inbox)
    case inbox.channel_type
    when 'Channel::Email'
      raise ArgumentError, 'Este portal requiere un correo electrónico.' if @email.blank?
    end
  end

  # [A] find_or_create contacto + contact_inbox del inbox destino (por email/teléfono).
  def build_contact_inbox(inbox)
    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      contact_attributes: {
        name:         @name.presence,
        email:        @email,
        phone_number: @phone
      }
    ).perform
  end

  # [B] reusa la conversación abierta del contacto EN EL INBOX DEL PORTAL; si no hay,
  # crea una nueva ahí. Así el acuse sale por el canal definido en el portal.
  # Devuelve [conversation, is_new].
  def resolve_conversation(contact, contact_inbox)
    existing = contact.conversations
                      .where(account_id: @account.id, inbox_id: contact_inbox.inbox_id,
                             status: REUSABLE_STATUSES)
                      .order(last_activity_at: :desc, created_at: :desc)
                      .first
    return [existing, false] if existing

    conversation = ConversationBuilder.new(
      params: ActionController::Parameters.new({}),
      contact_inbox: contact_inbox
    ).perform
    [conversation, true]
  end

  # Solo se aceptan tipos PÚBLICOS del portal; si el id no es público, cae al default.
  def resolved_case_type_id
    return nil if @case_type_id.blank?

    @portal.public_case_types.where(id: @case_type_id).pick(:id)
  end

  def ticket_title
    @subject.presence || @message.truncate(100).presence || 'Solicitud del portal'
  end
end
