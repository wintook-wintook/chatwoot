# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Resumen del negocio»: análisis de conversaciones con IA
# ================================================================================
# Servicio: Cases::Ai::ConversationAnalyst
#
# A pedido (botón «Analizar»: cuesta tokens). Toma una MUESTRA de las
# conversaciones del período (las más recientes, máx. SAMPLE_SIZE), con un extracto
# de sus mensajes (sin notas privadas) y si el cliente ya tiene una oportunidad
# abierta, y encuentra:
#   topics      de qué nos están hablando (máx. 5, con ejemplos)
#   upset       clientes molestos (para revisar)
#   lost_sales  preguntaron precio/disponibilidad y no tienen oportunidad abierta
#   complaints  quejas que se repiten
# Los ejemplos son números de conversación (display_id) y se filtran contra la
# muestra enviada: nunca se propone una conversación ajena o inventada.
# Devuelve un Hash o nil ante cualquier fallo.
# ================================================================================

class Cases::Ai::ConversationAnalyst < Cases::Ai::BaseService
  SAMPLE_SIZE = 150
  MESSAGES_PER_CONVERSATION = 8
  CHARS_PER_MESSAGE = 220
  MAX_ITEMS = 5
  MAX_EXAMPLES = 3

  # range: período a analizar (Range de tiempos) o nil.
  def analyze(range: nil)
    sample = sample_conversations(range)
    return { 'sample_size' => 0 } if sample.empty?

    raw = chat(system: system_prompt, user: user_prompt(sample), json: true, temperature: 0.2, max_tokens: 1500)
    return nil if raw.blank?

    sanitize(raw, sample.map(&:display_id)).merge('sample_size' => sample.size)
  end

  private

  def sample_conversations(range)
    scope = @account.conversations
    scope = scope.where(last_activity_at: range) if range
    scope.order(last_activity_at: :desc).limit(SAMPLE_SIZE).includes(:inbox).to_a
  end

  def system_prompt
    <<~PROMPT.strip
      Eres el analista de atención al cliente de un negocio. Recibes una muestra de
      conversaciones con clientes (por canal), con extractos de mensajes: «C:» es el
      cliente y «A:» el negocio. Encuentra, en español y en lenguaje de dueño:
        - topics: de qué hablan los clientes (máx. 5 temas, del más al menos frecuente).
        - upset: clientes molestos o insatisfechos que conviene revisar (máx. 5).
        - lost_sales: clientes que preguntaron precio, cotización o disponibilidad y
          NO tienen oportunidad abierta («oportunidad: no») (máx. 5).
        - complaints: quejas que se repiten en varias conversaciones (máx. 5).
      Usa SOLO lo que está en la muestra; no inventes clientes ni conversaciones. Los
      ejemplos son los números de conversación (#) que recibiste.
      Responde EXCLUSIVAMENTE con un objeto JSON:
        {
          "topics": [{ "label": "tema", "count": 12, "examples": [101, 87] }],
          "upset": [{ "conversation": 101, "why": "en una frase" }],
          "lost_sales": [{ "conversation": 87, "why": "qué preguntó" }],
          "complaints": [{ "label": "queja", "count": 4, "examples": [55] }]
        }
    PROMPT
  end

  def user_prompt(sample)
    with_opportunity = contacts_with_open_opportunity(sample)
    messages = excerpts(sample)
    lines = sample.map do |convo|
      opp = with_opportunity.include?(convo.contact_id) ? 'sí' : 'no'
      head = "##{convo.display_id} · #{convo.inbox&.channel_type.to_s.delete_prefix('Channel::')} · oportunidad: #{opp}"
      ([head] + Array(messages[convo.id])).join("\n")
    end
    "CONVERSACIONES (#{sample.size}):\n\n#{lines.join("\n\n")}"
  end

  def contacts_with_open_opportunity(sample)
    @account.case_tickets.commercial.where(status: CaseTicket::PENDING_STATUSES,
                                           contact_id: sample.filter_map(&:contact_id).uniq)
            .distinct.pluck(:contact_id).to_set
  end

  # conversación → ["C: …", "A: …"] (los primeros mensajes, recortados).
  def excerpts(sample)
    rows = Message.where(conversation_id: sample.map(&:id), private: false, message_type: %i[incoming outgoing])
                  .where.not(content: [nil, '']).order(:created_at)
                  .pluck(:conversation_id, :message_type, :content)
    rows.group_by(&:first).transform_values do |list|
      list.first(MESSAGES_PER_CONVERSATION).map do |_id, type, content|
        "#{type.to_s == 'incoming' ? 'C' : 'A'}: #{content.to_s.squish.truncate(CHARS_PER_MESSAGE)}"
      end
    end
  end

  def sanitize(raw, ids)
    {
      'topics' => groups(raw['topics'], ids),
      'upset' => singles(raw['upset'], ids),
      'lost_sales' => singles(raw['lost_sales'], ids),
      'complaints' => groups(raw['complaints'], ids)
    }
  end

  def groups(list, ids)
    Array(list).filter_map do |item|
      next unless item.is_a?(Hash) && item['label'].present?

      examples = Array(item['examples']).map(&:to_i).select { |id| ids.include?(id) }.uniq.first(MAX_EXAMPLES)
      { 'label' => item['label'].to_s.strip, 'count' => item['count'].to_i, 'examples' => examples }
    end.first(MAX_ITEMS)
  end

  def singles(list, ids)
    items = Array(list).filter_map do |item|
      next unless item.is_a?(Hash)

      id = item['conversation'].to_i
      { 'conversation' => id, 'why' => item['why'].to_s.strip } if ids.include?(id)
    end
    items.uniq { |i| i['conversation'] }.first(MAX_ITEMS)
  end
end
