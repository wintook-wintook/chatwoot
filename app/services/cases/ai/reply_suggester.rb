# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3C — Respuesta sugerida desde la base de conocimiento
# ================================================================================
# Servicio: Cases::Ai::ReplySuggester
#
# A partir del título + descripción del ticket, busca contenido relevante en la
# base de conocimiento (embeddings sobre knowledge_items, igual que el bot) y
# redacta una respuesta sugerida al cliente apoyada SOLO en ese contexto.
# Devuelve { reply:, sources: } o nil ante fallo. Si no hay contexto relevante,
# `no_context: true` y reply nil (la UI lo informa).
# ================================================================================

class Cases::Ai::ReplySuggester < Cases::Ai::BaseService
  MAX_SOURCES = 4
  THRESHOLD = 0.2

  def suggest(ticket)
    query = [ticket.title, ticket.description].compact.join("\n").strip
    return { 'reply' => nil, 'sources' => [], 'no_context' => true } if query.blank?

    embedding = embed(query)
    return nil if embedding.blank?

    items = ticket.account.knowledge_items.search_by_embedding(embedding, limit: MAX_SOURCES, threshold: THRESHOLD)
    return { 'reply' => nil, 'sources' => [], 'no_context' => true } if items.blank?

    reply = chat(
      system: system_prompt,
      user:   user_prompt(query, items),
      temperature: 0.3,
      max_tokens: 600
    )
    return nil if reply.blank?

    { 'reply' => reply, 'sources' => items.map { |i| source_json(i) }, 'no_context' => false }
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres un agente de soporte de Kontrolya. Redacta una respuesta al cliente en
      español, clara, cordial y profesional, basándote ÚNICAMENTE en el contexto de
      la base de conocimiento que se te da. No inventes datos. Si el contexto no
      cubre la consulta, dilo y sugiere escalar con un asesor. No incluyas saludos
      de firma ni "Atentamente"; ve directo a la solución.
    PROMPT
  end

  def user_prompt(query, items)
    context = items.each_with_index.map do |item, idx|
      "[#{idx + 1}] #{item.title.presence || 'Sin título'}\n#{item.content.to_s[0, 1500]}"
    end.join("\n\n")

    <<~PROMPT.strip
      CONSULTA DEL CLIENTE:
      #{query}

      CONTEXTO DE LA BASE DE CONOCIMIENTO:
      #{context}
    PROMPT
  end

  def source_json(item)
    {
      'title'       => item.title.presence || 'Sin título',
      'source_type' => item.source_type
    }
  end
end
