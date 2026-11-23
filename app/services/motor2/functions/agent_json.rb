# frozen_string_literal: true

# Motor 2.0 — un agente de función como lo ve su asistente y su tarjeta en Agentes listos (la misma
# forma que tenían los agentes listos de antes): { id, kind, name, display_name, enabled,
# inbox_ids, settings, testing, live_sessions, finished }. settings = las respuestas del
# asistente + las indicaciones (motor2['instructions']).
module Motor2::Functions::AgentJson
  LIVE = %w[pending scheduled active].freeze

  module_function

  # Las respuestas del asistente + indicaciones, bienvenida y lo que cambió de «Cómo habla tu empresa».
  def settings(motor2)
    motor2['answers'].to_h.merge('instructions' => motor2['instructions'].to_s, 'welcome' => motor2['welcome'].to_s,
                                 'voice' => motor2['voice'].to_h, 'voice_mode' => motor2['voice_mode'].to_s)
  end

  def call(template)
    motor2 = template.motor2.to_h
    { id: template.id, kind: template.agent_function, name: template.name, display_name: template.customer_display_name,
      enabled: template.attending, inbox_ids: Array(template.attend_inbox_ids).map(&:to_i), testing: template.testing,
      settings: settings(motor2),
      sources: Array(motor2['sources']), created_at: template.created_at }
      .merge(sessions(template)).merge(channel(template))
  end

  # «Vendedor de campaña»: por dónde escribe y sus toques (Motor2::Functions::Form#assign_channel).
  def channel(template)
    { channel: { inbox_id: template.inbox_id, whatsapp_templates: Array(template.whatsapp_templates), attempts: template.follow_up_attempts,
                 retry_value: template.retry_interval_value, retry_unit: template.retry_interval_unit,
                 email_signature: template.email_signature.to_s },
      campaigns: TrackingCampaign.where(tracking_template_id: template.id).count, files: template.file_rules }
      .merge(template.agent_function == 'collections' ? { collections: Receivables::Overview.agent(template) } : {})
  end

  # Cuántas pláticas atiende ahora y cómo terminaron las demás (calificado, pasado, descartado, era cliente).
  def sessions(template)
    rows = ContactTracking.where(tracking_template_id: template.id).pluck(:status, :outcome)
    finished = Hash.new(0)
    live = 0
    rows.each do |status, outcome|
      result = result_of(status, outcome)
      result == 'live' ? live += 1 : (finished[result] += 1 if result)
    end
    { live_sessions: live, finished: finished }
  end

  # «handed_off: Soporte» (Atención a clientes), «relayed: Ana» (Vendedor de campaña).
  PREFIXES = %w[handed_off relayed].freeze
  OUTCOMES = { 'handed_off' => 'handed_off', 'discarded' => 'discarded', 'rejected' => 'discarded', 'client' => 'client',
               'not_client' => 'not_client' }.freeze

  def result_of(status, outcome)
    text = outcome.to_s
    prefix = PREFIXES.find { |p| text.start_with?(p) }
    return prefix if prefix
    return 'live' if LIVE.include?(status.to_s)
    return OUTCOMES[text] if OUTCOMES.key?(text)

    'qualified' if text.start_with?('qualified', 'Cita') || status.to_s == 'objective_met'
  end
end
