# @knowledge_sources
# Job para sincronizar un topic individual de Discourse.
# Obtiene el contenido via API, lo divide en chunks, genera embeddings y hace upsert en knowledge_items.
# bulk: true → decrementa sync_jobs_pending en la fuente y finaliza cuando llega a 0.
class DiscourseTopicSyncJob < ApplicationJob
  queue_as :low

  # Chunking: ~1,500 tokens por chunk (6,000 chars), bien por debajo del límite de 8,191 tokens.
  # El solapamiento preserva contexto entre chunks contiguos.
  CHUNK_SIZE    = 6_000
  CHUNK_OVERLAP = 800

  def perform(source_id:, topic_id:, action:, bulk: false, category_name: nil, attempt: 0)
    @skip_finalize = false
    source  = KnowledgeSource.find_by(id: source_id)
    return unless source

    account = source.account
    config  = source.config || {}

    case action
    when 'upsert'
      result = upsert_topic(account, source, config, topic_id, category_name, attempt: attempt)
      if result == :rate_limited && attempt < 3
        wait = (attempt + 1) * 20 + rand(10)
        Rails.logger.warn "[DiscourseTopicSync] 429 topic #{topic_id}, re-encolando en #{wait}s (intento #{attempt + 1}/4)"
        self.class.set(wait: wait.seconds).perform_later(
          source_id: source_id, topic_id: topic_id, action: action,
          bulk: bulk, category_name: category_name, attempt: attempt + 1
        )
        @skip_finalize = true  # El job re-encolado decrementará el contador cuando termine
      elsif result == :rate_limited
        Rails.logger.warn "[DiscourseTopicSync] Topic #{topic_id} — 429 persistente tras 4 intentos, se omite"
      end
    when 'destroy'
      KnowledgeItem.where(account_id: account.id, source_type: 'discourse', source_id: topic_id).destroy_all
    end
  ensure
    finalize_bulk(source) if bulk && source && !@skip_finalize
  end

  private

  def finalize_bulk(source)
    source.with_lock do
      source.reload
      remaining = [source.sync_jobs_pending - 1, 0].max
      if remaining.zero?
        source.update!(sync_status: 'idle', sync_jobs_pending: 0, last_synced_at: Time.current)
        Rails.logger.info "[DiscourseTopicSync] Source #{source.id} bulk sync completed"
      else
        source.update_column(:sync_jobs_pending, remaining)
      end
    end
  rescue StandardError => e
    Rails.logger.error "[DiscourseTopicSync] Error finalizing bulk for source #{source.id}: #{e.message}"
  end

  def upsert_topic(account, source, config, topic_id, category_name = nil, attempt: 0)
    topic = fetch_topic(config, topic_id)
    return :rate_limited if topic == :rate_limited
    return unless topic
    return if category_about_topic?(config, topic)

    title   = topic['title'].to_s.strip
    content = extract_content(topic)
    return if content.blank?

    chunks   = split_into_chunks(content)
    total    = chunks.size
    cat_id   = topic['category_id'].to_i
    cat_name = category_name || fetch_category_name(config, cat_id)
    url      = "#{config['url'].to_s.chomp('/')}/t/#{topic['slug']}/#{topic_id}"

    # Eliminar chunks obsoletos si el topic se redujo
    KnowledgeItem.where(account_id: account.id, source_type: 'discourse', source_id: topic_id)
                 .where('chunk_index >= ?', total)
                 .destroy_all

    chunks.each_with_index do |chunk_text, idx|
      chunk_title   = total > 1 ? "#{title} (#{idx + 1}/#{total})" : title
      text_to_embed = "#{chunk_title}\n\n#{chunk_text}"
      embedding     = generate_embedding(account, text_to_embed)
      next unless embedding

      item = KnowledgeItem.find_or_initialize_by(
        account_id:  account.id,
        source_type: 'discourse',
        source_id:   topic_id,
        chunk_index: idx
      )

      item.assign_attributes(
        knowledge_source_id: source.id,
        title:     chunk_title,
        content:   chunk_text,
        embedding: embedding,
        metadata:  {
          url:           url,
          tags:          topic['tags'] || [],
          category:      cat_id,
          category_name: cat_name,
          chunk_index:   idx,
          chunk_total:   total
        }
      )
      item.save!
    end

    Rails.logger.info "[DiscourseTopicSync] Upserted topic #{topic_id} — #{title} (#{total} chunk(s))"
  end

  # Divide el texto en chunks de CHUNK_SIZE chars con CHUNK_OVERLAP de solapamiento.
  # Respeta límites naturales: primero párrafos, luego oraciones.
  def split_into_chunks(text)
    return [text] if text.length <= CHUNK_SIZE

    segments = split_into_segments(text)
    chunks   = []
    buffer   = +''

    segments.each do |seg|
      candidate = buffer.empty? ? seg : "#{buffer}\n\n#{seg}"

      if candidate.length > CHUNK_SIZE && buffer.present?
        chunks << buffer.strip
        # Solapamiento: cola del chunk anterior para preservar contexto
        overlap = buffer.length > CHUNK_OVERLAP ? buffer.last(CHUNK_OVERLAP).sub(/\A\S+\s*/, '') : buffer
        buffer  = overlap.blank? ? +seg : +"#{overlap}\n\n#{seg}"
      else
        buffer = +candidate
      end
    end

    chunks << buffer.strip if buffer.present?
    chunks.reject(&:blank?)
  end

  # Divide en párrafos; si un párrafo supera CHUNK_SIZE, lo subdivide por oraciones.
  def split_into_segments(text)
    text.split(/\n{2,}/).flat_map do |para|
      para = para.strip
      next [] if para.blank?

      if para.length <= CHUNK_SIZE
        [para]
      else
        para.scan(/[^.!?]+[.!?]+(?:\s|$)|[^.!?]+$/).map(&:strip).reject(&:blank?)
      end
    end
  end

  def extract_content(topic)
    first_post = topic.dig('post_stream', 'posts', 0)
    return nil unless first_post

    sanitizer = ActionView::Base.full_sanitizer
    body = sanitizer.sanitize(first_post['cooked'].to_s).squish

    body.presence || topic['title'].to_s.strip.presence
  end

  # Devuelve true si el topic es el "About the X category" creado automáticamente por Discourse.
  # Cada categoría tiene un topic_id que apunta a ese topic especial — lo comparamos con la categoría del topic.
  def category_about_topic?(config, topic)
    topic_id    = topic['id'].to_i
    category_id = topic['category_id'].to_i
    return false unless category_id.positive?

    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['username'].to_s.presence || 'system'

    uri  = URI("#{base_url}/c/#{category_id}/show.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 8

    req = Net::HTTP::Get.new(uri)
    req['Api-Key']      = api_key if api_key.present?
    req['Api-Username'] = api_username
    res = http.request(req)
    return false unless res.is_a?(Net::HTTPSuccess)

    cat_data          = JSON.parse(res.body)['category'] || {}
    category_topic_id = cat_data['topic_id'].to_i
    if category_topic_id.zero?
      # Algunas versiones omiten topic_id pero incluyen topic_url: /t/slug/ID
      category_topic_id = cat_data['topic_url'].to_s.split('/').last.to_i
    end
    topic_id == category_topic_id
  rescue StandardError
    false
  end

  def fetch_category_name(config, category_id)
    return nil unless category_id.positive?

    base_url = config['url'].to_s.chomp('/')
    uri      = URI("#{base_url}/c/#{category_id}/show.json")
    http     = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 8

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = config['api_key'].to_s if config['api_key'].present?
    request['Api-Username'] = config['username'].to_s.presence || 'system'

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('category', 'name')
  rescue StandardError
    nil
  end

  def fetch_topic(config, topic_id)
    base_url     = config['url'].to_s.chomp('/')
    api_key      = config['api_key'].to_s
    api_username = config['username'].to_s.presence || 'system'

    uri  = URI("#{base_url}/t/#{topic_id}.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = api_key
    request['Api-Username'] = api_username
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    return :rate_limited if response.code.to_i == 429

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "[DiscourseTopicSync] HTTP #{response.code} fetching topic #{topic_id} — skipping"
      return nil
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "[DiscourseTopicSync] Error fetching topic #{topic_id}: #{e.message}"
    nil
  end

  def generate_embedding(account, text)
    api_key = openai_api_key(account)
    return unless api_key

    uri  = URI('https://api.openai.com/v1/embeddings')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type']  = 'application/json'
    request.body = { model: 'text-embedding-3-small', input: text }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('data', 0, 'embedding')
  rescue StandardError => e
    Rails.logger.error "[DiscourseTopicSync] Error generating embedding: #{e.message}"
    nil
  end

  def openai_api_key(account)
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook&.settings&.dig('api_key').present?

    ENV['OPENAI_API_KEY']
  end
end
