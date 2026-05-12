# @knowledge_sources
# Controlador para la base de conocimiento semántica.
# Endpoints: CRUD de fuentes + búsqueda semántica por similitud coseno.
class Api::V1::Accounts::KnowledgeBaseController < Api::V1::Accounts::BaseController
  before_action :set_source, only: %i[update destroy sync]

  # GET /api/v1/accounts/:account_id/knowledge_base/items
  def items
    items = current_account.knowledge_items.order(updated_at: :desc)
    items = items.where(source_type: params[:source_type]) if params[:source_type].present?
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
      source_type: item.source_type,
      source_id: item.source_id,
      title: item.title,
      content: item.content,
      metadata: item.metadata,
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
