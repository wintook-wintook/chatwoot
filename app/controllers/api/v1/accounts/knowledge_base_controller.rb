# @knowledge_sources
# Controlador para la base de conocimiento semántica.
# Endpoints: CRUD de fuentes + búsqueda semántica por similitud coseno.
class Api::V1::Accounts::KnowledgeBaseController < Api::V1::Accounts::BaseController
  before_action :set_source, only: %i[update destroy sync]

  # GET /api/v1/accounts/:account_id/knowledge_base/items
  def items
    items = current_account.knowledge_items.order(updated_at: :desc)
    items = items.where(knowledge_source_id: params[:knowledge_source_id]) if params[:knowledge_source_id].present?
    items = items.where(source_type: params[:source_type]) if params[:source_type].present?
    items = items.where("metadata->>'category' = ?", params[:category_id].to_s) if params[:category_id].present?
    items = items.where('content ILIKE ? OR title ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    total = items.count
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, 1].max, 100].min
    per_page = 5 if per_page.zero?

    render json: {
      items: items.offset((page - 1) * per_page).limit(per_page).map { |i| item_json(i) },
      total: total
    }
  end

  # GET /api/v1/accounts/:account_id/knowledge_base/item_categories?knowledge_source_id=X
  # Devuelve las categorías distintas presentes en los items de una fuente.
  def item_categories
    items = current_account.knowledge_items.where("metadata ? 'category'")
    items = items.where(knowledge_source_id: params[:knowledge_source_id]) if params[:knowledge_source_id].present?

    cats = items
      .pluck(Arel.sql("DISTINCT metadata->>'category', metadata->>'category_name'"))
      .filter_map { |id, name| { id: id, name: name.presence || id } if id.present? }
      .sort_by { |c| c[:name] }

    render json: { categories: cats }
  end

  # GET /api/v1/accounts/:account_id/knowledge_base/sources
  def sources
    current_account.knowledge_sources.find_or_create_by(source_type: 'canned_response') do |s|
      s.name = 'Respuestas Predefinidas'
      s.status = 'active'
    end
    render json: current_account.knowledge_sources.order(:created_at)
  end

  # POST /api/v1/accounts/:account_id/knowledge_base/sources
  def create_source
    source = current_account.knowledge_sources.new(source_params)
    if source.save
      if source.source_type == 'discourse'
        provision_discourse_webhook(source)
        DiscourseKnowledgeSyncJob.perform_later(source_id: source.id)
      end
      render json: source, status: :created
    else
      render json: { errors: source.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/accounts/:account_id/knowledge_base/sources/:id
  def update
    old_config         = @source.config || {}
    old_category_ids   = old_config.dig('category_ids').to_a.map(&:to_i).select(&:positive?)

    permitted = source_params
    if permitted[:config] && old_config['discourse_webhook_id']
      permitted = permitted.merge(
        config: permitted[:config].merge('discourse_webhook_id' => old_config['discourse_webhook_id'])
      )
    end

    if @source.update(permitted)
      handle_category_changes(@source, old_category_ids) if @source.source_type == 'discourse'
      update_discourse_webhook(@source) if @source.source_type == 'discourse'
      render json: @source
    else
      render json: { errors: @source.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/accounts/:account_id/knowledge_base/sources/:id
  def destroy
    delete_discourse_webhook(@source) if @source.source_type == 'discourse'
    @source.destroy
    head :no_content
  end

  # POST /api/v1/accounts/:account_id/knowledge_base/sources/:id/sync
  def sync
    case @source.source_type
    when 'canned_response'
      sync_canned_responses
    when 'discourse'
      DiscourseKnowledgeSyncJob.perform_later(source_id: @source.id)
    end
    render json: { message: 'Sincronización iniciada' }
  end

  # POST /api/v1/accounts/:account_id/knowledge_base/discourse_categories
  def discourse_categories
    url          = params[:url].to_s.chomp('/')
    api_key      = params[:api_key].to_s
    api_username = params[:api_username].presence || 'system'

    return render json: { error: 'url requerida' }, status: :bad_request if url.blank?

    uri  = URI("#{url}/categories.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 8
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = api_key if api_key.present?
    request['Api-Username'] = api_username
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      msg = if response.is_a?(Net::HTTPForbidden) || response.is_a?(Net::HTTPUnauthorized)
              'API Key inválida o sin permisos suficientes en Discourse.'
            else
              "Discourse respondió con error #{response.code}. Verifica la URL."
            end
      return render json: { error: msg }, status: :unprocessable_entity
    end

    data = JSON.parse(response.body)
    categories = data.dig('category_list', 'categories')&.map do |c|
      { id: c['id'], name: c['name'], slug: c['slug'], topic_count: c['topic_count'].to_i }
    end || []

    render json: { categories: categories }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/knowledge_base/search
  def search
    query = params[:query].to_s.strip
    return render json: { error: 'query requerido' }, status: :bad_request if query.blank?

    embedding = generate_embedding(query)
    return render json: { error: 'No se pudo generar el embedding' }, status: :unprocessable_entity unless embedding

    results = current_account.knowledge_items
                             .search_by_embedding(embedding, limit: params[:limit] || 5, threshold: params[:threshold] || 0.7)
                             .map do |item|
      {
        id: item.id,
        source_type: item.source_type,
        source_id: item.source_id,
        title: item.title,
        content: item.content,
        metadata: item.metadata,
        similarity: (1 - item.neighbor_distance).round(4)
      }
    end

    render json: { results: results }
  end

  private

  def item_json(item)
    {
      id: item.id,
      knowledge_source_id: item.knowledge_source_id,
      source_type: item.source_type,
      source_id: item.source_id,
      title: item.title,
      content: item.content,
      metadata: item.metadata,
      created_at: item.created_at,
      updated_at: item.updated_at
    }
  end

  def set_source
    @source = current_account.knowledge_sources.find(params[:id])
  end

  def source_params
    params.require(:knowledge_source).permit(:name, :source_type, :status, config: {})
  end

  def handle_category_changes(source, old_ids)
    new_ids = source.config&.dig('category_ids').to_a.map(&:to_i).select(&:positive?)

    return if old_ids == new_ids

    if new_ids.empty?
      # Volvió a modo "todas las categorías": sincronizar el foro completo
      DiscourseKnowledgeSyncJob.perform_later(source_id: source.id) if old_ids.any?
      return
    end

    if old_ids.empty?
      # Pasó de "todas" a categorías específicas: eliminar lo que no pertenece
      source.knowledge_items
            .where("metadata->>'category' IS NOT NULL")
            .where.not("(metadata->>'category')::int = ANY(ARRAY[?]::int[])", new_ids)
            .destroy_all
    else
      # Cambio entre conjuntos: eliminar categorías removidas
      removed = old_ids - new_ids
      if removed.any?
        source.knowledge_items
              .where("(metadata->>'category')::int = ANY(ARRAY[?]::int[])", removed)
              .destroy_all
        Rails.logger.info "[KnowledgeBase] Source #{source.id} — deleted items from categories #{removed.join(', ')}"
      end
    end

    # Sincronizar categorías recién agregadas
    added = new_ids - old_ids
    DiscourseKnowledgeSyncJob.perform_later(source_id: source.id) if added.any?
  end

  # ── Discourse webhook provisioning ──────────────────────────────────────────

  DISCOURSE_WEBHOOK_EVENT_NAMES = %w[
    topic_created topic_edited topic_destroyed post_created post_edited post_destroyed
  ].freeze

  # Fetches event type IDs from Discourse by matching event names across all known endpoints.
  # Falls back to wildcard (nil) if event types cannot be determined.
  def fetch_discourse_event_type_ids(base_url, api_key, api_username)
    # Strategy 1: dedicated endpoint (available in some Discourse versions)
    ids = fetch_event_ids_from_types_endpoint(base_url, api_key, api_username)
    return ids if ids&.any?

    # Strategy 2: extract from existing webhooks that have event types set
    fetch_event_ids_from_existing_webhooks(base_url, api_key, api_username)
  rescue StandardError
    nil
  end

  def fetch_event_ids_from_types_endpoint(base_url, api_key, api_username)
    http = discourse_http(base_url, api_key)
    uri  = URI("#{base_url}/admin/api/web_hook_event_types.json")

    req = Net::HTTP::Get.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Accept']       = 'application/json'

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    types = JSON.parse(res.body)
    types = types['web_hook_event_types'] if types.is_a?(Hash)
    ids = types.filter_map { |t| t['id'] if DISCOURSE_WEBHOOK_EVENT_NAMES.include?(t['name']) }
    ids.any? ? ids : nil
  rescue StandardError
    nil
  end

  def fetch_event_ids_from_existing_webhooks(base_url, api_key, api_username)
    http = discourse_http(base_url, api_key)
    uri  = URI("#{base_url}/admin/api/web_hooks.json")

    req = Net::HTTP::Get.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Accept']       = 'application/json'

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    hooks = JSON.parse(res.body)['web_hooks'] || []
    all_types = hooks.flat_map { |h| h['web_hook_event_types'] || [] }.uniq { |t| t['id'] }
    ids = all_types.filter_map { |t| t['id'] if DISCOURSE_WEBHOOK_EVENT_NAMES.include?(t['name']) }
    ids.any? ? ids : nil
  rescue StandardError
    nil
  end

  def provision_discourse_webhook(source)
    config       = source.config || {}
    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['api_username'].presence || 'system'
    secret       = config['webhook_secret'].to_s
    return if base_url.blank? || api_key.blank?

    payload_url = "#{ENV.fetch('FRONTEND_URL', request.base_url).chomp('/')}/webhooks/discourse/#{source.id}"

    webhook_id = discourse_create_webhook(base_url, api_key, api_username, payload_url, secret)
    return unless webhook_id

    source.update_column(:config, config.merge('discourse_webhook_id' => webhook_id))
    Rails.logger.info "[KnowledgeBase] Discourse webhook #{webhook_id} created for source #{source.id}"
    discourse_ping_webhook(base_url, api_key, api_username, webhook_id)
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] Error provisioning webhook: #{e.message}"
  end

  def update_discourse_webhook(source)
    config       = source.config || {}
    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['api_username'].presence || 'system'
    webhook_id   = config['discourse_webhook_id'].to_i
    secret       = config['webhook_secret'].to_s
    return if base_url.blank? || api_key.blank?

    payload_url = "#{ENV.fetch('FRONTEND_URL', request.base_url).chomp('/')}/webhooks/discourse/#{source.id}"

    if webhook_id.positive?
      discourse_update_webhook(base_url, api_key, api_username, webhook_id, payload_url, secret)
    else
      provision_discourse_webhook(source)
    end
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] Error updating webhook: #{e.message}"
  end

  def delete_discourse_webhook(source)
    config       = source.config || {}
    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['api_username'].presence || 'system'
    webhook_id   = config['discourse_webhook_id'].to_i
    return unless base_url.present? && api_key.present? && webhook_id.positive?

    discourse_delete_webhook(base_url, api_key, api_username, webhook_id)
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] Error deleting webhook: #{e.message}"
  end

  def discourse_http(base_url, _api_key)
    uri  = URI(base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 8
    http.read_timeout = 10
    http
  end

  def discourse_create_webhook(base_url, api_key, api_username, payload_url, secret)
    event_ids = fetch_discourse_event_type_ids(base_url, api_key, api_username)
    wildcard  = event_ids.nil?

    http = discourse_http(base_url, api_key)
    uri  = URI("#{base_url}/admin/api/web_hooks")

    req = Net::HTTP::Post.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Content-Type'] = 'application/json'
    req['Accept']       = 'application/json'
    req.body = {
      web_hook: {
        payload_url:             payload_url,
        content_type:            1,
        secret:                  secret,
        wildcard_web_hook:       wildcard,
        web_hook_event_type_ids: wildcard ? [] : event_ids,
        active:                  true,
        verify_certificate:      true
      }
    }.to_json

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).dig('web_hook', 'id')
  end

  def discourse_update_webhook(base_url, api_key, api_username, webhook_id, payload_url, secret)
    event_ids = fetch_discourse_event_type_ids(base_url, api_key, api_username)
    wildcard  = event_ids.nil?

    http = discourse_http(base_url, api_key)
    uri  = URI("#{base_url}/admin/api/web_hooks/#{webhook_id}")

    req = Net::HTTP::Put.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Content-Type'] = 'application/json'
    req['Accept']       = 'application/json'
    req.body = {
      web_hook: {
        payload_url:             payload_url,
        content_type:            1,
        secret:                  secret,
        wildcard_web_hook:       wildcard,
        web_hook_event_type_ids: wildcard ? [] : event_ids,
        active:                  true,
        verify_certificate:      true
      }
    }.to_json

    http.request(req)
  end

  def discourse_ping_webhook(base_url, api_key, api_username, webhook_id)
    http = discourse_http(base_url, api_key)
    uri  = URI("#{base_url}/admin/api/web_hooks/#{webhook_id}/ping")

    req = Net::HTTP::Post.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Content-Type'] = 'application/json'
    req['Accept']       = 'application/json'
    req.body = '{}'

    http.request(req)
    Rails.logger.info "[KnowledgeBase] Discourse webhook #{webhook_id} pinged"
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] Error pinging webhook: #{e.message}"
  end

  def discourse_delete_webhook(base_url, api_key, api_username, webhook_id)
    http = discourse_http(base_url, api_key)
    uri   = URI("#{base_url}/admin/api/web_hooks/#{webhook_id}")

    req = Net::HTTP::Delete.new(uri)
    req['Api-Key']      = api_key
    req['Api-Username'] = api_username
    req['Content-Type'] = 'application/json'
    req['Accept']       = 'application/json'

    http.request(req)
  end

  def sync_canned_responses
    current_account.canned_responses.find_each do |cr|
      KnowledgeItemSyncJob.perform_later(
        action: 'upsert',
        source_type: 'canned_response',
        source_id: cr.id,
        account_id: current_account.id
      )
    end
    @source.update(last_synced_at: Time.current)
  end

  def generate_embedding(text)
    api_key = openai_api_key
    return unless api_key

    uri = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[KnowledgeBase] Error generating embedding: #{e.message}"
    nil
  end

  def openai_api_key
    hook = current_account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end
end
