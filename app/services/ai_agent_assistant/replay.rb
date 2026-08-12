# ================================================================================
# proyecto@ai_agent_assistant - F7
# ================================================================================
# Servicio: AiAgentAssistant::Replay
# Descripción: Corre el Agente IA contra mensajes REALES de conversaciones ya
#              cerradas de ese inbox, y pone al lado lo que contestó la persona.
#
# Es la evaluación honesta del módulo. El probador manual prueba con lo que a uno
# se le ocurre escribir; el replay prueba con lo que los clientes escriben de
# verdad, que casi nunca es lo mismo. Y como la respuesta humana está guardada, se
# puede comparar en vez de opinar.
#
# Solo lee. No crea Message, no reabre conversaciones, no toca nada. Y el tope de
# conversaciones es duro porque cada una cuesta una llamada al modelo.
# ================================================================================

class AiAgentAssistant::Replay
  MAX_CONVERSATIONS = 5
  DEFAULT_CONVERSATIONS = 3
  MIN_MESSAGE_LENGTH = 8

  def initialize(template, limit: DEFAULT_CONVERSATIONS)
    @template = template
    @limit = limit.to_i.clamp(1, MAX_CONVERSATIONS)
  end

  def call
    return { 'error' => 'no_inbox', 'cases' => [] } if template.inbox_id.blank?

    pairs = sample_pairs
    return { 'error' => 'no_conversations', 'cases' => [] } if pairs.empty?

    { 'inbox_id' => template.inbox_id, 'cases' => pairs.map { |pair| replay(pair) } }
  end

  private

  attr_reader :template, :limit

  def sandbox
    @sandbox ||= AiAgentAssistant::SandboxService.new(template)
  end

  # Conversaciones cerradas del mismo inbox, las más recientes. De cada una, el
  # primer mensaje real del cliente y la primera respuesta humana que vino después.
  # `lazy` + `first(limit)`: se pide de más porque muchas conversaciones no sirven
  # (sin respuesta humana, mensajes vacíos), pero se para en cuanto hay suficientes.
  # Sin ese corte, un inbox con historial dispararía una llamada al modelo por cada
  # conversación cerrada.
  def sample_pairs
    conversations.lazy.filter_map { |conversation| pair_from(conversation) }.first(limit)
  end

  def conversations
    template.account.conversations
            .where(inbox_id: template.inbox_id, status: :resolved)
            .order(created_at: :desc)
            .limit(limit * 4)
  end

  def pair_from(conversation)
    messages = conversation.messages.where(private: false).order(:created_at)
    customer = messages.find { |message| usable?(message, 'incoming') }
    return nil if customer.nil?

    human = messages.find do |message|
      message.created_at > customer.created_at && usable?(message, 'outgoing')
    end
    return nil if human.nil?

    { conversation: conversation, customer: customer, human: human }
  end

  def usable?(message, type)
    message.message_type == type && message.content.to_s.strip.length >= MIN_MESSAGE_LENGTH
  end

  def replay(pair)
    answer = sandbox.reply(pair[:customer].content)

    {
      'conversation_id' => pair[:conversation].display_id,
      'customer' => pair[:customer].content,
      'human' => pair[:human].content,
      'agent' => answer['text'],
      'route' => answer['route'],
      'tokens_used' => answer['tokens_used'],
      'truncated' => answer['truncated'],
      'would_have' => answer['would_have'],
      'error' => answer['error']
    }.compact
  end
end
