# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — «VER MÁS» DE UNA BÚSQUEDA QUE SE CORTÓ (20/11/2026, Seminuevos Valera)
# ================================================================================
# {{hoja_buscar}} como fuente da hasta SIZE filas y avisa «(y N más)». Antes, a «¿cuáles son
# las otras?» el motor repetía la misma búsqueda, le daba al modelo las mismas primeras filas
# y el agente las repetía o inventaba las que faltaban.
#
# Ahora la búsqueda cortada se guarda en la conversación (por Agente IA, como welcome_sent):
# qué ruta, qué directiva, qué se buscó, cuántas filas se mostraron y en qué mensaje. Toca la
# página siguiente solo si:
#   · el mensaje anterior del agente es ESE (si habló de otra cosa, ya no aplica);
#   · el cliente pide más con palabras claras («las otras», «el resto», «ver más»…), o
#     contesta que sí y el agente le había preguntado si quería ver las demás;
#   · la búsqueda, corrida otra vez, da los mismos criterios (si nombró otra cosa —«¿y las
#     sedán?»— es una búsqueda nueva). Eso lo revisa KnowledgeBaseResponseService.
# ================================================================================

module ContactTrackings::SheetLookup::Pages
  STORE_KEY = 'lookup_pages'
  SIZE = 20
  # Pedir más sin decir de qué. «más» suelto no: «¿y el más barato?» es otra pregunta.
  MORE_RE = /
    \b(?:otr[oa]s|el\s+resto|l[oa]s\s+dem[aá]s|siguientes|faltan|faltantes|restantes|
    (?:ver|mand(?:a|ame|e)|mu[eé]str(?:a|ame)|pasa(?:me)?|d(?:a|ame)|hay|cu[aá]les|tienes|tienen)\s+m[aá]s
    (?!\s+(?:de|que|del|caro|caros|barato|baratos|econ[oó]mic|nuev|viej|grande|chic|\d))|
    m[aá]s\s+(?:opciones|unidades|autos|carros|coches|productos))\b
  /ix
  YES_RE = /\A[¡!¿\s]*(?:s[ií]+|sip|va|ok(?:ay)?|claro|dale|por\s*favor|porfa|me\s+interesa|[aá]ndale|quiero\s+ver(?:las|los)?)\b/i
  MAX_YES_WORDS = 6
  # La pregunta del agente ofrecía ver las demás («¿Quieres ver las otras 5?»).
  OFFER_RE = /otr[oa]s|resto|dem[aá]s|m[aá]s\s+(?:opciones|unidades)|ver(?:las|los)|restantes/i

  module_function

  # La página guardada si a este mensaje le toca la siguiente, o nil.
  def pending(tracking, conversation, message)
    page = stored(tracking, conversation)
    return nil if page.nil? || message&.content.blank?

    last = last_reply(conversation, message)
    page if last&.id == page['message_id'] && asks_more?(message.content, last.content)
  end

  def stored(tracking, conversation)
    return nil if tracking.nil? || conversation.nil?

    # De la base: se guarda con update_columns sobre otra copia de la conversación.
    Conversation.where(id: conversation.id).pick(:additional_attributes).to_h.dig(STORE_KEY, key(tracking)).presence
  end

  def asks_more?(content, last_reply)
    return true if content.match?(MORE_RE)

    content.split.size <= MAX_YES_WORDS && content.match?(YES_RE) && offered?(last_reply)
  end

  # La última pregunta del agente ofrecía ver más.
  def offered?(text)
    pregunta = text.to_s.scan(/¿[^?]*\?/).last
    pregunta.present? && pregunta.match?(OFFER_RE)
  end

  # page: { 'route', 'directive', 'criteria', 'shown', 'total' }. Se guarda con el mensaje que
  # la mostró; si ya se mostró todo (o no se mandó), se borra.
  def save(tracking, conversation, reply, page)
    return if tracking.nil? || conversation.nil?

    store(tracking, conversation, reply && page['shown'] < page['total'] ? page.merge('message_id' => reply.id) : nil)
  end

  def store(tracking, conversation, page)
    Conversation.transaction do
      locked = Conversation.lock.find(conversation.id)
      attrs = locked.additional_attributes || {}
      pages = attrs[STORE_KEY].to_h.except(key(tracking))
      pages[key(tracking)] = page if page
      next if pages == attrs[STORE_KEY].to_h

      locked.update_columns(additional_attributes: attrs.merge(STORE_KEY => pages)) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def last_reply(conversation, message)
    conversation.messages.where(message_type: :outgoing, private: false).where(id: ...message.id).reorder(id: :desc).first
  end

  def key(tracking)
    ContactTrackings::ConversationVariables.store_key(tracking)
  end
end
