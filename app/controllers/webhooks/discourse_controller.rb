# @knowledge_sources
# Recibe webhooks de Discourse para sincronizar topics en tiempo real.
# URL: POST /webhooks/discourse/:source_id
# Discourse firma cada request con HMAC-SHA256 usando el webhook_secret.
class Webhooks::DiscourseController < ActionController::API
  TOPIC_EVENTS = %w[topic_created topic_edited topic_destroyed].freeze
  POST_EVENTS  = %w[post_created post_edited post_destroyed].freeze

  def process_payload
    source = KnowledgeSource.find_by(id: params[:source_id], source_type: 'discourse')
    return head :not_found unless source

    return head :unauthorized unless valid_signature?(source)

    event = request.headers['X-Discourse-Event']
    return head :ok unless TOPIC_EVENTS.include?(event) || POST_EVENTS.include?(event)

    topic_id = resolve_topic_id(event)
    return head :unprocessable_entity unless topic_id

    return head :ok unless allowed_category?(source, event)

    action = (event == 'topic_destroyed' || event == 'post_destroyed') ? 'destroy' : 'upsert'

    DiscourseTopicSyncJob.perform_later(
      source_id: source.id,
      topic_id:  topic_id,
      action:    action
    )

    head :ok
  end

  private

  def resolve_topic_id(event)
    if POST_EVENTS.include?(event)
      # post_created / post_edited → el payload trae `post` con topic_id
      post = params[:post]
      post&.dig(:topic_id)&.to_i.then { |id| id&.positive? ? id : nil }
    else
      # topic_created / topic_edited / topic_destroyed → payload trae `topic`
      topic = params[:topic]
      topic&.dig(:id)&.to_i.then { |id| id&.positive? ? id : nil }
    end
  end

  def allowed_category?(source, event)
    category_ids = source.config&.dig('category_ids')
    return true if category_ids.blank?

    allowed = category_ids.map(&:to_i)

    topic_category_id = if POST_EVENTS.include?(event)
                          params.dig(:post, :category_id).to_i
                        else
                          params.dig(:topic, :category_id).to_i
                        end

    allowed.include?(topic_category_id)
  end

  def valid_signature?(source)
    secret = source.config&.dig('webhook_secret')
    return true if secret.blank?

    expected  = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)}"
    received  = request.headers['X-Discourse-Event-Signature'].to_s

    ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end
end
