# frozen_string_literal: true

# @tickets_cases — «Resumen del negocio»: bloque de CONVERSACIONES (¿cómo estamos
# atendiendo por chat?). Usa los mismos cálculos que «Informes → Conversaciones»
# de Chatwoot (V2::Reports::Conversations::MetricBuilder y V2::ReportBuilder),
# para que las cifras coincidan: nuevas, resueltas, primera respuesta y resolución
# (segundos), con su período de comparación; abiertas / sin atender / sin asignar
# (foto de hoy); satisfacción, por canal y de qué hablan (las etiquetas más usadas).
# Requiere `account`, `params` y `range` del builder.
module V2::Reports::Cases::BusinessSummaryConversations
  TOP_LABELS = 5

  private

  def conversations_block
    @conversations_block ||= conversation_numbers(params[:since], params[:until])
                             .merge(previous: previous_conversation_numbers, now: live_conversations,
                                    csat: conversation_csat, by_channel: conversations_by_channel,
                                    top_labels: top_conversation_labels)
  end

  def conversation_numbers(since, till)
    summary = V2::Reports::Conversations::MetricBuilder.new(account, { type: :account, since: since.to_s,
                                                                       until: till.to_s }).summary
    { new_count: summary[:conversations_count], resolved_count: summary[:resolutions_count],
      avg_first_response_seconds: summary[:avg_first_response_time]&.to_f&.round,
      avg_resolution_seconds: summary[:avg_resolution_time]&.to_f&.round }
  end

  def previous_conversation_numbers
    since, till = params.values_at(:prev_since, :prev_until)
    since.present? && till.present? ? conversation_numbers(since, till) : nil
  end

  def live_conversations
    V2::ReportBuilder.new(account, { type: :account }).conversation_metrics
  end

  def conversations_in_range
    scope = account.conversations
    range ? scope.where(created_at: range) : scope
  end

  def conversation_csat
    responses = account.csat_survey_responses
    responses = responses.where(created_at: range) if range
    count = responses.count
    { avg: count.zero? ? nil : responses.average(:rating)&.to_f&.round(2), count: count }
  end

  # Canal → cantidad («Channel::Whatsapp» → «whatsapp»).
  def conversations_by_channel
    conversations_in_range.joins(:inbox).group('inboxes.channel_type').count
                          .map { |type, n| { channel: type.to_s.delete_prefix('Channel::').underscore, count: n } }
                          .sort_by { |r| -r[:count] }
  end

  def top_conversation_labels
    ActsAsTaggableOn::Tagging.where(taggable_type: 'Conversation', context: 'labels',
                                    taggable_id: conversations_in_range.select(:id))
                             .joins(:tag).group('tags.name').order(Arel.sql('COUNT(*) DESC'))
                             .limit(TOP_LABELS).count
                             .map { |name, n| { label: name, count: n } }
  end
end
