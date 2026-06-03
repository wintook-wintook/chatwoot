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
      DiscourseKnowledgeSyncJob.perform_later(source_id: source.id) if source.source_type == 'discourse'
      render json: source, status: :created
    else
      render json: { errors: source.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/accounts/:account_id/knowledge_base/sources/:id
  def update
    if @source.update(source_params)
      render json: @source
    else
      render json: { errors: @source.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/accounts/:account_id/knowledge_base/sources/:id
  def destroy
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

  # GET /api/v1/accounts/:account_id/knowledge_base/search_settings
  def search_settings
    settings = current_account.custom_attributes&.dig('kbase_search') || {}
    render json: {
      similarity_threshold: settings['similarity_threshold'] || KnowledgeBaseResponseService::DEFAULTS['similarity_threshold'],
      max_results:          (settings['max_results'] || KnowledgeBaseResponseService::DEFAULTS['max_results']).to_i,
      max_context_chars:    (settings['max_context_chars'] || KnowledgeBaseResponseService::DEFAULTS['max_context_chars']).to_i
    }
  end

  # PATCH /api/v1/accounts/:account_id/knowledge_base/search_settings
  def update_search_settings
    threshold = params[:similarity_threshold].to_f.clamp(0.1, 0.99)
    max_res   = params[:max_results].to_i.clamp(1, 20)
    max_chars = params[:max_context_chars].to_i.clamp(500, 10_000)

    attrs = (current_account.custom_attributes || {}).merge(
      'kbase_search' => {
        'similarity_threshold' => threshold,
        'max_results'          => max_res,
        'max_context_chars'    => max_chars
      }
    )
    current_account.update!(custom_attributes: attrs)

    render json: { similarity_threshold: threshold, max_results: max_res, max_context_chars: max_chars }
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
