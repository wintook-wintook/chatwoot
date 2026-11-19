# frozen_string_literal: true

# Motor 2.0 — un agente de función como lo ve su asistente y su tarjeta en Agentes listos (la misma
# forma que tenían los agentes listos de antes): { id, kind, name, display_name, enabled,
# inbox_ids, settings, testing, live_sessions, finished }. settings = las respuestas del
# asistente + las indicaciones (motor2['instructions']).
module Motor2::Functions::AgentJson
  LIVE = %w[pending scheduled active].freeze

  module_function

  def call(template)
    motor2 = template.motor2.to_h
    { id: template.id, kind: template.agent_function, name: template.name, display_name: template.customer_display_name,
      enabled: template.attending, inbox_ids: Array(template.attend_inbox_ids).map(&:to_i), testing: template.testing,
      settings: motor2['answers'].to_h.merge('instructions' => motor2['instructions'].to_s), created_at: template.created_at }
      .merge(sessions(template))
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

  OUTCOMES = { 'handed_off' => 'handed_off', 'discarded' => 'discarded', 'rejected' => 'discarded', 'client' => 'client' }.freeze

  def result_of(status, outcome)
    text = outcome.to_s
    return 'handed_off' if text == 'handed_off'
    return 'live' if LIVE.include?(status.to_s)
    return OUTCOMES[text] if OUTCOMES.key?(text)

    'qualified' if text.start_with?('qualified', 'Cita') || status.to_s == 'objective_met'
  end
end
