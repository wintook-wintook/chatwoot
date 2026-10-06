# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Directiva @estado_ticket (consulta de estado por el canal)
# ================================================================================
# Servicio: Cases::TicketStatusService
# Responsabilidad: cuando el complementary_prompt tiene @estado_ticket y el cliente
# pregunta por su caso ("¿cuál es mi ticket?", "¿cómo va mi caso?"), responde por
# el mismo canal con el folio y el estado de sus tickets — sin que teclee el folio.
#
# Retorna true si respondió, false si no aplica (deja seguir el flujo del job).
# Ver: docs/vault-tickets/implementacion/Plan-Crear-Ticket-IA.md · [[Pendiente]] (@estado_ticket P2)
#
# Posición en el flujo (try_kbase_then_conversational): va ANTES de @crear_ticket,
# porque preguntar por un caso existente no debe abrir uno nuevo.
# ================================================================================

class Cases::TicketStatusService
  DIRECTIVE = '@estado_ticket'

  # Sustantivos de "caso" + señales de consulta de estado. Requiere AMBOS para
  # disparar, así "necesito un ticket" (alta) no se confunde con "mi ticket" (estado).
  NOUNS = /\b(ticket|tickets|caso|casos|folio|reporte|reclamo|solicitud|incidencia)\b/i
  CUES  = /\b(cu[aá]l|cu[aá]les|c[oó]mo|estado|status|situaci[oó]n|seguimiento|avance|va|mi|mis|tengo|abiert)\b/i

  # Etiquetas de estado amigables para el cliente (no la jerga ITIL interna).
  FRIENDLY_STATUS = {
    'open'                   => 'Recibido, en revisión',
    'classified'             => 'Recibido, en revisión',
    'assigned'               => 'Asignado a un asesor',
    'in_diagnosis'           => 'En diagnóstico',
    'in_progress'            => 'En proceso',
    'waiting_on_customer'    => 'En espera de tu respuesta',
    'waiting_on_third_party' => 'En espera de un tercero',
    'waiting_on_internal'    => 'En proceso (revisión interna)',
    'escalated'              => 'Escalado a un especialista',
    'resolved'              => 'Resuelto',
    'validating'             => 'En validación',
    'closed'                 => 'Cerrado',
    'cancelled'              => 'Cancelado'
  }.freeze

  MAX_LISTED = 3

  def initialize(message, tracking:)
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @conversation = message.conversation
    @contact      = message.conversation.contact
  end

  def answer_if_status_query
    return false unless directive_present?
    return false unless status_query?

    deliver(build_reply)
    true
  rescue StandardError => e
    Rails.logger.error "[TicketStatus] Error respondiendo estado: #{e.message}"
    false
  end

  private

  def directive_present?
    @tracking&.complementary_prompt.to_s.include?(DIRECTIVE)
  end

  def status_query?
    text = @message.content.to_s
    return false if text.blank?

    NOUNS.match?(text) && CUES.match?(text)
  end

  # Tickets del contacto, del más reciente al más viejo (excluye cancelados).
  def tickets
    return [] unless @contact

    @account.case_tickets
            .where(contact_id: @contact.id)
            .where.not(status: 'cancelled')
            .order(created_at: :desc)
            .limit(MAX_LISTED)
            .to_a
  end

  def build_reply
    found = tickets
    return no_tickets_reply if found.empty?

    if found.one?
      one_ticket_reply(found.first)
    else
      many_tickets_reply(found)
    end
  end

  def one_ticket_reply(ticket)
    "Tu caso #{folio(ticket)} — “#{ticket.title.to_s.truncate(80)}” — está: " \
      "#{friendly(ticket)}. Si necesitas algo más, escríbeme por aquí."
  end

  def many_tickets_reply(list)
    lines = list.map { |t| "• #{folio(t)} — #{friendly(t)} (#{t.title.to_s.truncate(50)})" }
    "Estos son tus casos más recientes:\n#{lines.join("\n")}"
  end

  def no_tickets_reply
    'No encuentro un caso registrado a tu nombre. ¿Quieres que levante uno?'
  end

  def folio(ticket)
    ticket.folio.presence || "##{ticket.id}"
  end

  def friendly(ticket)
    FRIENDLY_STATUS[ticket.status.to_s] || ticket.status.to_s.humanize
  end

  def deliver(text)
    reply = Messages::MessageBuilder.new(
      bot_user, @conversation, { content: text, private: false }
    ).perform
    return if reply.blank?

    reply.content_attributes[:ticket_status] = true
    reply.save!
  end

  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end
end
