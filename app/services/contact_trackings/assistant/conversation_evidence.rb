# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — UNA CONVERSACIÓN REAL COMO EVIDENCIA (revisión de conversaciones)
# ================================================================================
# La persona pega en el chat del Asistente el link de una conversación
# (…/app/accounts/2/conversations/173) para que se revise qué contestó mal el agente
# (pedido del usuario, 24/09/2026). Esta clase junta la evidencia SIN IA:
#
#   · los mensajes, en orden: cliente, bot, persona del equipo, nota interna
#   · el seguimiento (ContactTracking) que la atendió y su Agente IA
#   · el Entrenamiento que CORRIÓ: el motor contesta con la copia que se guarda en el
#     seguimiento al iniciarlo (complementary_prompt), no con el del Agente IA. Medido
#     en la 173: el agente 8884 ya no tenía #humano y la conversación seguía con él.
#
# Solo la cuenta de quien pregunta: la conversación se busca por su número dentro de
# Current.account, nunca por id global.
#
# Lo que sale hacia OpenAI va enmascarado (PhraseMasker: correos, teléfonos, RFC…).
# ================================================================================

class ContactTrackings::Assistant::ConversationEvidence
  # /app/accounts/2/conversations/173, o «conversación 173» / «conversacion #173».
  LINK_RE = %r{/accounts/(\d+)/conversations/(\d+)}
  PLAIN_RE = /\bconversaci[oó]n\s*#?\s*(\d+)\b/i

  # Una conversación larga no cabe entera ni hace falta: lo que se revisa suele ser
  # lo último. Se toman los últimos mensajes y se avisa que hay más.
  MAX_MESSAGES = 40
  MAX_CHARS = 700

  Turn = Struct.new(:n, :role, :content, :at, :message_id, keyword_init: true)

  # El número de conversación que trae un texto, o nil. Si el link es de OTRA cuenta
  # también devuelve nil: no se mezclan cuentas aunque la persona tenga acceso a las dos.
  def self.display_id_in(text, account)
    link = text.to_s.match(LINK_RE)
    return (link[1].to_i == account.id ? link[2].to_i : nil) if link

    text.to_s[PLAIN_RE, 1]&.to_i
  end

  attr_reader :conversation

  def initialize(account, display_id)
    @account = account
    @conversation = account.conversations.find_by(display_id: display_id)
  end

  def found?
    @conversation.present?
  end

  # El seguimiento más reciente de la conversación: es el que contestó lo último.
  def tracking
    return nil unless found?

    @tracking ||= ContactTracking.where(account: @account, conversation: @conversation).order(:id).last
  end

  def template
    tracking&.tracking_template
  end

  # Lo que el motor tenía para contestar.
  def ran_prompt
    tracking&.complementary_prompt.to_s
  end

  # El Agente IA cambió después de iniciarse el seguimiento: lo que se corrija en el
  # agente NO le llega a esta conversación.
  def stale_copy?
    template.present? && ran_prompt.present? && template.complementary_prompt.to_s != ran_prompt
  end

  # El motor lee el calendario del Agente IA y, si no tiene, del seguimiento (ver
  # ContactTrackingResponseAnalyzerJob#calendar_configured?).
  def calendar_configured?
    (template&.calendar_integration_ids.presence || tracking&.calendar_integration_ids).present?
  end

  def turns
    @turns ||= messages.each_with_index.map do |m, i|
      Turn.new(n: i + 1, role: role_of(m), message_id: m.id, at: m.created_at,
               content: ContactTrackings::Assistant::PhraseMasker.call(m.content.to_s.strip).truncate(MAX_CHARS))
    end
  end

  def truncated?
    total_messages > MAX_MESSAGES
  end

  def total_messages
    @total_messages ||= scope.count
  end

  private

  def messages
    scope.order(:created_at, :id).last(MAX_MESSAGES)
  end

  # Sin actividad («asignado a…») ni mensajes vacíos (un adjunto sin texto).
  def scope
    @conversation.messages.where(message_type: %i[incoming outgoing template]).where.not(content: [nil, ''])
  end

  # El bot responde como un User, con una marca: sentiment_auto_reply (respuestas) o
  # las del envío del seguimiento (ContactTrackingJob). Una persona del equipo no lleva
  # ninguna. Lo privado es nota interna (la confirmación de la cita, p. ej.).
  BOT_MARKS = %w[sentiment_auto_reply automation_rule_id whatsapp_template_name].freeze

  def role_of(message)
    return 'cliente' if message.incoming?
    return 'nota' if message.private?
    return 'bot' if message.sender_type != 'User'

    message.content_attributes.to_h.keys.map(&:to_s).intersect?(BOT_MARKS) ? 'bot' : 'humano'
  end
end
