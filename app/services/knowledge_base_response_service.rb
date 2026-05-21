# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - BASE DE CONOCIMIENTO
# ================================================================================
# Servicio: KnowledgeBaseResponseService
#
# Genera una respuesta usando knowledge_items cuando el complementary_prompt
# contiene una de las siguientes directivas:
#
#   @buscar_predeterminadas          → busca en items de tipo canned_response
#   @buscar_foro(nombre_del_foro)    → busca en el KnowledgeSource con ese nombre
#
# RETORNO:
#   true  → se encontraron resultados y se envió respuesta
#   false → sin resultados o error (el caller hace fallback conversacional)
# ================================================================================

class KnowledgeBaseResponseService
  SIMILARITY_THRESHOLD = 0.72
  MAX_RESULTS          = 5
  MAX_CONTEXT_CHARS    = 2000

  def initialize(message, tracking: nil)
    @message  = message
    @tracking = tracking
    @account  = message.account
  end

  def perform
    directive = detect_directive
    unless directive
      Rails.logger.info '[KBase] ⏭️  Sin directiva kbase en complementary_prompt → skip'
      return false
    end

    Rails.logger.info "[KBase] 🔍 Modo: #{directive[:mode]}#{" (#{directive[:source_name]})" if directive[:source_name]}"

    embedding = generate_embedding(message_text)
    return false unless embedding

    items = search_items(directive, embedding)
    if items.empty?
      Rails.logger.info '[KBase] ⚠️  Sin resultados relevantes'
      return false
    end

    Rails.logger.info "[KBase] ✅ #{items.size} resultado(s) encontrado(s)"

    context = build_context(items)
    reply   = generate_reply(context)
    return false if reply.blank?

    source_tag = source_name_for(directive)
    send_reply("#{reply}\n\n_#{source_tag}_")
    true

  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    false
  end

  private

  # ==============================================================================
  # Detección de directiva
  # ==============================================================================
  def detect_directive
    cp = @tracking&.complementary_prompt.to_s
    if cp.include?('@buscar_predeterminadas')
      { mode: :canned_response }
    elsif (match = cp.match(/@buscar_foro\(([^)]+)\)/i))
      { mode: :knowledge_source, source_name: match[1].strip }
    end
  end

  # ==============================================================================
  # Búsqueda semántica
  # ==============================================================================
  def search_items(directive, embedding)
    scope = @account.knowledge_items

    case directive[:mode]
    when :canned_response
      scope = scope.where(source_type: 'canned_response')
    when :knowledge_source
      source = @account.knowledge_sources.active.find_by(name: directive[:source_name])
      unless source
        Rails.logger.warn "[KBase] ⚠️  KnowledgeSource '#{directive[:source_name]}' no encontrado o inactivo"
        return []
      end
      scope = scope.where(knowledge_source_id: source.id)
    end

    scope.search_by_embedding(embedding, limit: MAX_RESULTS, threshold: SIMILARITY_THRESHOLD)
  end

  def build_context(items)
    items.map.with_index(1) do |item, i|
      header = item.title.present? ? "#{i}. #{item.title}" : "#{i}."
      "#{header}\n#{item.content.truncate(600)}"
    end.join("\n\n").truncate(MAX_CONTEXT_CHARS)
  end

  # ==============================================================================
  # Generación de respuesta con OpenAI
  # ==============================================================================
  def generate_reply(context)
    api_key = openai_api_key
    return nil unless api_key

    first_name = @message.sender&.name&.split&.first || 'cliente'
    objective  = @tracking&.objective.to_s

    system_prompt = <<~SYSTEM.strip
      Eres un asesor de #{@account.name}. Responde como un humano amable y conocedor del tema.
      NUNCA menciones que eres un bot, sistema automático o que consultaste una base de datos.
      #{objective.present? ? "Objetivo de la conversación: #{objective}" : ""}
    SYSTEM

    user_prompt = <<~USER.strip
      El cliente #{first_name} preguntó: "#{message_text.truncate(300)}"

      Información relevante disponible:
      #{context}

      Responde usando esa información. Máximo 4 líneas. Tono natural y conversacional.
      No uses prefijos como "Asesor:" ni comillas al inicio o final.
    USER

    call_openai(api_key, system_prompt, user_prompt)
  end

  def call_openai(api_key, system_prompt, user_prompt)
    require 'net/http'
    require 'json'

    uri               = URI('https://api.openai.com/v1/chat/completions')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 10

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = {
      model:       'gpt-4o-mini',
      messages:    [
        { role: 'system', content: system_prompt },
        { role: 'user',   content: user_prompt }
      ],
      max_tokens:  250,
      temperature: 0.5
    }.to_json

    response = http.request(request)
    body     = JSON.parse(response.body)
    reply    = body.dig('choices', 0, 'message', 'content')&.strip
    reply&.gsub(/\A[A-Za-záéíóúñÁÉÍÓÚÑ\s]{2,20}:\s*\n?/, '')&.strip
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error OpenAI reply: #{e.message}"
    nil
  end

  # ==============================================================================
  # Embedding
  # ==============================================================================
  def generate_embedding(text)
    api_key = openai_api_key
    return nil unless api_key

    uri               = URI('https://api.openai.com/v1/embeddings')
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 10

    request                  = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error generando embedding: #{e.message}"
    nil
  end

  # ==============================================================================
  # Envío de respuesta
  # ==============================================================================
  def send_reply(text)
    reply_message = Messages::MessageBuilder.new(
      bot_user,
      @message.conversation,
      { content: text, private: false }
    ).perform

    if reply_message.present?
      reply_message.content_attributes[:sentiment_auto_reply] = true
      reply_message.save!
    end
  rescue StandardError => e
    Rails.logger.error "[KBase] ❌ Error enviando respuesta: #{e.message}"
  end

  # ==============================================================================
  # Utilidades
  # ==============================================================================
  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end

  def openai_api_key
    hook = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end

  def source_name_for(directive)
    case directive[:mode]
    when :canned_response
      source = @account.knowledge_sources.find_by(source_type: 'canned_response')
      source&.name || 'Respuestas Predefinidas'
    when :knowledge_source
      directive[:source_name]
    end
  end

  def message_text
    @message_text ||= @message.content.to_s.strip.presence || '[sin contenido]'
  end
end
