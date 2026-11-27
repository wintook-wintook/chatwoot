# frozen_string_literal: true

# Campaña con Vendedor IA — «Qué dicen los contactos»: con IA, de las respuestas de los contactos y los motivos de
# «no le interesa», 3 a 5 puntos para la empresa (qué preguntan, qué objeciones, qué mejorar en la oferta).
# Se guarda en campaign.brief['insights'] con su fecha; se recalcula a pedido.
class TrackingCampaigns::Motor2Insights < Cases::Ai::BaseService
  MAX_REPLIES = 60
  SYSTEM = <<~TEXT
    Eres analista de una campaña comercial. Te paso lo que contestaron los contactos y por qué dijeron que no les
    interesa. Escribe de 3 a 5 puntos cortos en español para la empresa: lo que más preguntan, las objeciones que se
    repiten, qué les interesó y una sugerencia concreta para mejorar la oferta o el mensaje. Sin inventar datos ni
    cifras que no estén. Responde solo JSON: {"puntos": ["…", "…"]}
  TEXT

  def initialize(campaign)
    super(account: campaign.account)
    @campaign = campaign
  end

  def call
    texts = replies
    return { points: [], error: 'Todavía no hay respuestas de los contactos.' } if texts.empty?

    result = chat(system: SYSTEM, user: user_text(texts), json: true, temperature: 0.2, max_tokens: 500)
    points = Array(result.is_a?(Hash) ? result['puntos'] : nil).map { |p| p.to_s.squish.first(300) }.compact_blank.first(5)
    @campaign.update!(brief: @campaign.brief.to_h.merge('insights' => { 'points' => points, 'at' => Time.current.iso8601 }))
    { points: points }
  rescue StandardError => e
    Rails.logger.warn("[Motor2Insights] #{e.class}: #{e.message}")
    { points: [], error: 'No se pudo armar el resumen.' }
  end

  private

  def model = AiModels::REVIEW

  def replies
    ids = ContactTracking.where(tracking_campaign_id: @campaign.id).where.not(conversation_id: nil).pluck(:conversation_id)
    Message.where(conversation_id: ids, message_type: :incoming).where('created_at >= ?', @campaign.created_at)
           .where.not(content: [nil, '']).where("#{AiFollowUp.message_attr_sql('auto_reply')} IS DISTINCT FROM 'true'") # sin las automáticas
           .order(created_at: :desc).limit(MAX_REPLIES).pluck(:content).map { |c| c.squish.first(300) }
  end

  def user_text(texts)
    reasons = TrackingCampaigns::Motor2Results.new(@campaign).call[:reasons]
    ["OFERTA: #{@campaign.brief.to_h['offer_what']}", 'RESPUESTAS:', *texts.map { |t| "- #{t}" },
     ('NO LE INTERESA (motivos):' if reasons.any?), *reasons.map { |r| "- #{r}" }].compact.join("\n")
  end
end
