# frozen_string_literal: true

# Campaña con IA · Encuesta — en Resultados: contestaron, promedio, bajas y casos, y además: el NPS de la pregunta de 0 a 10 (promotores 9–10,
# pasivos 7–8, detractores 0–6) y los comentarios de las preguntas abiertas (los 20 más recientes).
class TrackingCampaigns::SurveyResults
  MAX_COMMENTS = 20

  def initialize(campaign, trackings)
    @campaign = campaign
    @trackings = trackings
    @items = Array(campaign.brief.to_h['survey_items'])
  end

  def call
    scores = states.flat_map { |(state, _)| state['survey'].to_h.values.filter_map { |v| v['calificacion'] } }.map(&:to_f)
    { answered: states.count { |(state, _)| state['survey'].to_h.any? },
      average: scores.any? ? (scores.sum / scores.size).round(1) : nil, low: low_count,
      cases: @trackings.where('outcome LIKE ?', 'Encuesta baja%').count, nps: nps, comments: comments }
  end

  private

  # Respuestas bajas: con preguntas con tipo, según cada una; si no, menores a low_score.
  def low_count
    legacy = @campaign.brief.to_h['low_score'].to_i
    states.sum do |(state, _)|
      state['survey'].to_h.count { |n, v| TrackingCampaigns::SurveyItems.low?(@items, n, v['calificacion'], legacy) }
    end
  end

  def states = @states ||= @trackings.where("motor2_state ? 'survey'").order(updated_at: :desc).pluck(:motor2_state, :contact_id)

  def nps
    scores = nps_scores
    return if scores.empty?

    promoters = scores.count { |n| n >= 9 }
    detractors = scores.count { |n| n <= 6 }
    { score: (((promoters - detractors).to_f / scores.size) * 100).round, promoters: promoters,
      passives: scores.size - promoters - detractors, detractors: detractors, total: scores.size }
  end

  def nps_scores
    index = @items.index { |i| i['type'] == 'scale10' } || legacy_scale10
    return [] unless index

    states.filter_map { |(state, _)| state.dig('survey', (index + 1).to_s, 'calificacion') }.map(&:to_i)
  end

  # Sin preguntas con tipo: la primera que diga «del 0 al 10».
  def legacy_scale10
    Array(@campaign.brief.to_h['survey_questions']).index { |q| TrackingCampaigns::SurveyLink.range(q)&.max == 10 }
  end

  def open_numbers = @items.each_index.select { |i| @items[i]['type'] == 'open' }.map { |i| (i + 1).to_s }

  def comments
    numbers = open_numbers
    return [] if numbers.empty?

    names = Contact.where(id: states.map(&:last)).pluck(:id, :name).to_h
    states.flat_map { |(state, contact_id)| numbers.filter_map { |n| comment(state, n, names[contact_id]) } }.first(MAX_COMMENTS)
  end

  def comment(state, number, name)
    text = state.dig('survey', number, 'respuesta').to_s.strip
    { contact: name, question: @items[number.to_i - 1]['text'], answer: text } if text.present?
  end
end
