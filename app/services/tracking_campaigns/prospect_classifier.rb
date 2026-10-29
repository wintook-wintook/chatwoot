# frozen_string_literal: true

# ================================================================================
# prospeccion V5 — EN QUÉ VA CADA PROSPECTO (clasificar su respuesta)
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§8.1 etapas y salidas, §10.3 V5, D14, D15).
#
#   En todas las campañas (§10.12; antes solo Prospección). Con cada respuesta, una llamada corta
#   (gpt-4o-mini con JSON fijo; si falla, gpt-4o) elige UNA categoría:
#
#     interested      → etapa «interesado» + interested_at (ya cuenta en el embudo de campañas)
#     not_now         → salida «no ahora»: un solo toque más, en 30 días (casilla retry_not_now)
#     not_interested  → salida «no le interesa»: se cierra (casilla stop_when_not_interested)
#     wrong_person    → salida «no es la persona»: se cierra (casilla stop_when_wrong_person)
#     other           → etapa «respondió»
#
#   La etapa nunca baja (un interesado que luego saluda sigue interesado). La IA sigue
#   contestando como siempre. Si la llamada falla, queda «respondió»: nunca rompe el turno.
#   prospeccion P4.2: en la misma llamada, el motivo del interés (price · info · meeting) y si
#   quien responde decide; con eso se recalcula la puntuación (TrackingCampaigns::ProspectScore).
# ================================================================================
require 'net/http'

class TrackingCampaigns::ProspectClassifier
  LABELS = %w[interested not_now not_interested wrong_person other].freeze
  REASONS = %w[price info meeting].freeze # prospeccion P4.2: motivo del interés
  MODELS = %w[gpt-4o-mini gpt-4o].freeze
  STAGE_RANK = { nil => 0, 'replied' => 1, 'interested' => 2, 'handed_off' => 3 }.freeze
  WAITING_STATUSES = %w[pending scheduled].freeze
  NOT_NOW_DAYS = 30

  def self.call(tracking, message)
    new(tracking, message).call
  end

  def initialize(tracking, message)
    @tracking = tracking
    @message = message
  end

  # La categoría elegida, o nil si no aplica.
  def call
    return if campaign.nil? # §10.12: en todas las campañas, cualquier canal

    answer = MODELS.lazy.filter_map { |model| ask(model) }.first || { 'categoria' => 'other' }
    label = answer['categoria']
    apply(label, answer)
    Rails.logger.info "[ProspectClassifier] Tracking ##{@tracking.id}: #{label}"
    label
  rescue StandardError => e
    Rails.logger.warn "[ProspectClassifier] Tracking ##{@tracking.id}: #{e.message}"
    nil
  end

  private

  def apply(label, answer = {})
    attrs = { prospect_classified_at: Time.current,
              prospect_stage: stage_at_least(label == 'interested' ? 'interested' : 'replied') }
    attrs.merge!(outcome_attributes(label), signal_attributes(label, answer))
    return Rails.logger.warn("[ProspectClassifier] #{@tracking.errors.full_messages.join(', ')}") unless @tracking.update(attrs)

    TrackingCampaigns::ProspectScore.call(@tracking) # prospeccion P4
    auto_hand_off
  end

  # prospeccion P4.2: lo que la IA leyó para la puntuación. Los motivos se acumulan (pidió precio
  # y luego cita = los dos); «no se sabe» no borra un sí/no anterior.
  def signal_attributes(label, answer)
    attrs = {}
    reason = answer['motivo'].to_s
    attrs[:prospect_signals] = (Array(@tracking.prospect_signals) | [reason]) if label == 'interested' && REASONS.include?(reason)
    decides = answer['decide'].to_s
    attrs[:prospect_decision_maker] = decides if %w[yes no].include?(decides)
    attrs
  end

  # prospeccion P2: con tablero de entrega, el interesado entra solo a Oportunidades.
  # Si la entrega falla, el prospecto queda «interesado» (se puede entregar con el botón).
  def auto_hand_off
    return unless @tracking.prospect_stage == 'interested' && campaign.auto_handoff?

    TrackingCampaigns::HandOff.new(@tracking).call
  rescue StandardError => e
    Rails.logger.warn "[ProspectClassifier] entrega del tracking ##{@tracking.id}: #{e.message}"
  end

  # La salida SIEMPRE se anota (cuenta en el embudo); detener o reprogramar los toques depende
  # de las casillas de la campaña (§10.12, D20 y D25).
  def outcome_attributes(label)
    case label
    when 'interested' then { prospect_exit: nil, interested_at: @tracking.interested_at || Time.current }
    when 'not_now' then not_now_attributes
    when 'not_interested' then stop_attributes(label, campaign.stop_when_not_interested)
    when 'wrong_person' then stop_attributes(label, campaign.stop_when_wrong_person)
    else {}
    end
  end

  def stop_attributes(label, stop)
    { prospect_exit: label }.merge(stop && waiting? ? { status: 'completed' } : {})
  end

  def campaign
    @tracking.tracking_campaign
  end

  # D15: un solo toque más, a los 30 días (solo si esperaba su siguiente toque y la campaña
  # tiene prendida «ahora no → 30 días»).
  def not_now_attributes
    attrs = { prospect_exit: 'not_now' }
    return attrs unless waiting? && campaign.retry_not_now

    attrs.merge(scheduled_for: not_now_at, max_attempts: [@tracking.max_attempts, @tracking.attempt_count + 1].min)
  end

  def stage_at_least(stage)
    STAGE_RANK[@tracking.prospect_stage].to_i >= STAGE_RANK[stage] ? @tracking.prospect_stage : stage
  end

  def waiting?
    WAITING_STATUSES.include?(@tracking.status)
  end

  # D15: un solo toque, a los 30 días, nunca sábado ni domingo.
  def not_now_at
    time = (@message.created_at + NOT_NOW_DAYS.days).in_time_zone(@tracking.inbox&.timezone.presence || 'UTC')
    time += 1.day while time.saturday? || time.sunday?
    time
  end

  def ask(model)
    api_key = @message.account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
    return if api_key.blank?

    raw = JSON.parse(post_json(api_key, model)).dig('choices', 0, 'message', 'content').to_s
    answer = JSON.parse(raw).transform_values { |value| value.to_s.strip }
    LABELS.include?(answer['categoria']) ? answer : nil
  rescue StandardError => e
    Rails.logger.warn "[ProspectClassifier] #{model}: #{e.message}"
    nil
  end

  def post_json(api_key, model)
    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { model: model, messages: [{ role: 'user', content: prompt }], max_tokens: 60, temperature: 0,
                     response_format: { type: 'json_object' } }.to_json
    http.request(request).body
  end

  def prompt
    <<~PROMPT.strip
      Clasifica la respuesta de un prospecto a una campaña de ventas en frío.
      Objetivo de la campaña: #{@tracking.objective.to_s.truncate(300)}
      Lo último que le escribimos: "#{last_outgoing.truncate(400)}"
      Respuesta del prospecto: "#{ContactTrackings::AttachmentText.message_text(@message).strip.truncate(600)}"

      Elige UNA categoría:
      - interested: muestra interés, pide precio, información, una cita o una llamada.
      - not_now: le interesa pero no en este momento (más adelante, otro mes, ahorita no puede).
      - not_interested: no le interesa, ya tiene proveedor o no lo necesita.
      - wrong_person: no es la persona indicada, no decide o el dato es equivocado.
      - other: saludo, duda general o algo que no encaja en las anteriores.

      Si es interested, di el motivo principal:
      - price: pide precio, cotización o costos.
      - info: pide información, catálogo o detalles.
      - meeting: pide una cita, reunión, visita o llamada.

      ¿Quien responde decide la compra? yes (lo dice o se nota: dueño, gerente, «yo autorizo»),
      no (dice que no decide, lo pasa a otra persona), unknown (no se sabe).

      Responde SOLO un JSON: {"categoria": "<interested|not_now|not_interested|wrong_person|other>",
      "motivo": "<price|info|meeting|none>", "decide": "<yes|no|unknown>"}
    PROMPT
  end

  def last_outgoing
    @message.conversation.messages.where(message_type: :outgoing).where('created_at < ?', @message.created_at)
            .order(:created_at).last&.content.to_s
  end
end
