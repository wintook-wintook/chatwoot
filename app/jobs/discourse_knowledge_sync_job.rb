# @knowledge_sources
# Job para sincronización inicial (bulk) de todos los topics de un foro Discourse.
# Distribuye los jobs individuales en el tiempo (~400ms entre cada uno) para no superar
# el rate limit de Discourse (~200 req/min con API key).
# Actualiza sync_status y sync_jobs_pending en la fuente para que el frontend
# pueda mostrar el progreso.
class DiscourseKnowledgeSyncJob < ApplicationJob
  queue_as :default

  TOPICS_PER_PAGE  = 30
  SECONDS_PER_JOB  = 0.4  # 2.5 topics/seg → ~150/min, por debajo del límite de Discourse

  def perform(source_id:)
    source = KnowledgeSource.find_by(id: source_id, source_type: 'discourse')
    return unless source

    config       = source.config || {}
    base_url     = config['url'].to_s.chomp('/')
    category_ids = Array(config['category_ids']).map(&:to_i).select(&:positive?)

    return if base_url.blank?

    # Cargar mapa id → nombre de categorías y topic_ids de "About" una sola vez
    category_names, about_topic_ids = fetch_category_names(config, base_url)

    # Recopilar todos los topics antes de encolar para conocer el total
    # Cada entrada: { id:, category_id: }
    topics = if category_ids.any?
               category_ids.flat_map { |cat_id| collect_topics(config, base_url, cat_id, about_topic_ids) }
             else
               collect_topics(config, base_url, nil, about_topic_ids)
             end.uniq { |t| t[:id] }

    total = topics.size
    return if total.zero?

    # Marcar fuente como sincronizando
    source.update!(sync_status: 'syncing', sync_jobs_pending: total)

    # Encolar cada job con delay escalonado
    topics.each_with_index do |topic, idx|
      delay         = (idx * SECONDS_PER_JOB).seconds
      cat_id        = topic[:category_id]
      cat_name      = category_names[cat_id]

      DiscourseTopicSyncJob.set(wait: delay).perform_later(
        source_id:     source.id,
        topic_id:      topic[:id],
        action:        'upsert',
        bulk:          true,
        category_name: cat_name
      )
    end

    scope = category_ids.any? ? "categories #{category_ids.join(', ')}" : 'all categories'
    Rails.logger.info "[DiscourseKnowledgeSync] Source #{source.id} (#{scope}) — #{total} topics enqueued over #{(total * SECONDS_PER_JOB).round}s"
  end

  private

  def collect_topics(config, base_url, category_id, about_topic_ids = Set.new)
    topics = []
    page   = 0

    loop do
      page_topics = fetch_topics_page(config, base_url, category_id, page)
      break if page_topics.blank?

      page_topics.each do |t|
        next if t['id'].blank?
        next if t['archetype'] == 'private_message'
        next if about_topic_ids.include?(t['id'].to_i)
        topics << { id: t['id'].to_i, category_id: t['category_id'].to_i }
      end

      break if page_topics.size < TOPICS_PER_PAGE
      page += 1
    end

    topics
  end

  def fetch_category_names(config, base_url)
    data = discourse_get(config, URI("#{base_url}/categories.json"))
    cats = data&.dig('category_list', 'categories') || []
    names     = cats.each_with_object({}) { |c, h| h[c['id'].to_i] = c['name'] }
    about_ids = cats.filter_map { |c| category_about_topic_id(c) }.to_set
    [names, about_ids]
  rescue StandardError
    [{}, Set.new]
  end

  def category_about_topic_id(cat)
    id = cat['topic_id'].to_i
    return id if id.positive?

    # Algunas versiones de Discourse omiten topic_id pero incluyen topic_url: /t/slug/ID
    url = cat['topic_url'].to_s
    parsed = url.split('/').last.to_i
    parsed.positive? ? parsed : nil
  end

  def fetch_topics_page(config, base_url, category_id, page)
    path = category_id ? "/c/#{category_id}/l/latest.json" : '/latest.json'
    uri  = URI("#{base_url}#{path}")
    uri.query = URI.encode_www_form(page: page)

    discourse_get(config, uri)&.dig('topic_list', 'topics') || []
  rescue StandardError => e
    Rails.logger.error "[DiscourseKnowledgeSync] Error fetching page #{page}: #{e.message}"
    []
  end

  def discourse_get(config, uri, redirect_limit = 5)
    return nil if redirect_limit.zero?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 20

    request = Net::HTTP::Get.new(uri)
    request['Api-Key']      = config['api_key'].to_s if config['api_key'].present?
    request['Api-Username'] = config['api_username'].to_s.presence || 'system'
    request['Content-Type'] = 'application/json'

    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection)
      location = response['location']
      return nil if location.blank?

      new_uri = URI(location)
      new_uri = URI("#{uri.scheme}://#{uri.host}#{location}") unless new_uri.host
      return discourse_get(config, new_uri, redirect_limit - 1)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
