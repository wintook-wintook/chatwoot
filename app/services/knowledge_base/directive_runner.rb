# frozen_string_literal: true

# Ejecuta @buscar_predefinidas SIN conversación real: búsqueda + redacción, igual
# que KnowledgeBaseResponseService#perform_pgvector para 'canned_response', pero sin
# mandar nada a una conversación de Chatwoot. Para POST
# /knowledge_base/directive (equipos externos como Daiko).
#
# No reutiliza perform_pgvector directamente: esa rama termina en send_reply (crea
# un Message real sobre @conversation), que no existe en este flujo. Se reimplementan
# aquí solo la búsqueda y la redacción; kbase_setting SÍ se reutiliza
# (KnowledgeBaseResponseService.kbase_setting), para no duplicar la resolución de
# defaults por cuenta.
class KnowledgeBase::DirectiveRunner
  SOURCE_NAME    = 'Respuestas predefinidas'
  SOURCE_TYPE    = 'canned_response'
  EMBED_MODEL    = 'text-embedding-3-small'
  MAX_ITEM_CHARS = 1200

  def initialize(context)
    @context = context
    @account = context.account
  end

  def call
    return result(resolved: false, reason: :no_directive) if @context.query.blank?

    embedding = generate_embedding(@context.query)
    return result(resolved: false, reason: :embedding_failed) if embedding.blank?

    scope = @account.knowledge_items.where(source_type: SOURCE_TYPE)
    items = scope.search_by_embedding(embedding, limit: @context.max_results, threshold: @context.similarity_threshold)
    return result(resolved: false, reason: :no_match) if items.empty?

    items_payload = items_json(items)
    return result(resolved: true, items: items_payload, source: SOURCE_NAME) unless @context.compose

    reply = compose_reply(items)
    return result(resolved: false, items: items_payload, reason: :llm_empty) if reply.blank?

    result(resolved: true, items: items_payload, reply: reply, source: SOURCE_NAME)
  end

  private

  def result(resolved:, items: [], reply: nil, source: nil, reason: nil)
    KnowledgeBase::Result.new(
      resolved: resolved, threshold: @context.similarity_threshold, model: model_name,
      items: items, reply: reply, source: source, reason: reason
    )
  end

  def items_json(items)
    items.map do |item|
      {
        id: item.id,
        title: item.title,
        content: item.content,
        source_type: item.source_type,
        source_id: item.source_id,
        knowledge_source_id: item.knowledge_source_id,
        metadata: item.metadata,
        similarity: (1 - item.neighbor_distance).round(4)
      }
    end
  end

  def compose_reply(items)
    context_text = items.map.with_index(1) { |i, n| "#{n}. #{i.title}\n#{i.content.truncate(MAX_ITEM_CHARS)}" }
                        .join("\n\n")
                        .truncate(KnowledgeBaseResponseService.kbase_setting(@account, 'max_context_chars').to_i)

    messages = [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_prompt(context_text) }
    ]
    call_openai_chat(messages)&.strip.presence
  end

  def system_prompt
    "Eres un asesor de #{@account.name}. Responde como un humano amable y conocedor. " \
      'NUNCA menciones que eres un bot ni que consultaste una base de datos.'
  end

  def user_prompt(context_text)
    <<~USER.strip
      El cliente #{@context.contact_name} preguntó: "#{@context.query.truncate(300)}"

      Información relevante:
      #{context_text}

      Respondé usando esa información de forma completa y útil. Tono natural y conversacional.
      No uses prefijos como "Asesor:" ni comillas al inicio o final.
    USER
  end

  def model_name
    @model_name ||= ContactTrackings::EngineConfig.model_for(nil)
  end

  def call_openai_chat(messages)
    api_key = openai_api_key
    return nil if api_key.blank?

    uri               = URI('https://api.openai.com/v1/chat/completions')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 45

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: model_name, messages: messages, max_tokens: 800, temperature: 0.5 }.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content')&.strip
  rescue StandardError => e
    Rails.logger.error "[KBase::DirectiveRunner] Error OpenAI chat: #{e.message}"
    nil
  end

  def generate_embedding(text)
    api_key = openai_api_key
    return nil if api_key.blank?

    uri               = URI('https://api.openai.com/v1/embeddings')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 10

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: EMBED_MODEL, input: text }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KBase::DirectiveRunner] Error embedding: #{e.message}"
    nil
  end

  # Cada cuenta usa su propia integración OpenAI (sin fallback a ENV global, multi-tenant).
  def openai_api_key
    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key').presence
  end
end
