# frozen_string_literal: true

# Motor 2.0 — cómo le va a un agente de «Atención a prospectos» (últimos DAYS días):
#   - cuántos atendió y cómo terminaron (calificado, con cita, pasado a una persona, descartado, era cliente,
#     sin respuesta) y el % que calificó o agendó;
#   - en qué pregunta se van los que dejan de contestar (la primera que les faltaba);
#   - de qué anuncio de clic a WhatsApp vienen y cuántos de cada uno calificaron.
#
#   Motor2::ProspectMetrics.new(template).call → { total:, results: {…}, conversion:, drop_off: [{ question:, count: }], ads: [...] }
class Motor2::ProspectMetrics
  DAYS = 30
  IDLE = 24.hours
  GOOD = %w[qualified appointment].freeze

  def initialize(template, days: DAYS)
    @template = template
    @since = days.days.ago
  end

  def call
    rows = trackings.map { |t| [t, result(t)] }
    results = rows.map(&:last).tally
    total = rows.size
    good = GOOD.sum { |k| results[k].to_i }
    { days: (Time.current - @since).round / 1.day, total: total, results: results, groups: {},
      conversion: total.zero? ? 0 : (good * 100.0 / total).round, drop_off: drop_off(rows), ads: ads(rows) }
  end

  private

  def trackings
    ContactTracking.where(tracking_template_id: @template.id).where(created_at: @since..).includes(:conversation).to_a
  end

  # Cómo terminó (o «live» si sigue platicando, «no_answer» si dejó de contestar).
  def result(tracking)
    outcome = tracking.outcome.to_s
    return 'appointment' if outcome.start_with?('Cita')
    return 'qualified' if outcome.start_with?('qualified') || tracking.status == 'objective_met'
    return outcome if %w[handed_off discarded client].include?(outcome)
    return 'no_answer' if idle?(tracking)

    'live'
  end

  def idle?(tracking)
    tracking.status == 'completed' || (Motor2::LIVE.include?(tracking.status) && tracking.updated_at < IDLE.ago)
  end

  # La pregunta que le faltaba a cada uno de los que dejaron de contestar.
  def drop_off(rows)
    questions = Motor2::Config.new(@template).function.questions
    counts = rows.select { |(_, r)| r == 'no_answer' }.map { |(tracking, _)| missing(questions, tracking) }.tally
    counts.sort_by { |_, n| -n }.map { |question, count| { question: question, count: count } }
  end

  def missing(questions, tracking)
    answered = tracking.motor2_state.to_h['answers'].to_h
    questions.find { |q| !answered.key?(q[:ask]) }&.dig(:ask) || 'después de contestar todas'
  end

  def ads(rows)
    grouped = rows.group_by { |(tracking, _)| tracking.conversation&.additional_attributes.to_h.dig('ad_referral', 'headline') }
    list = grouped.except(nil).map { |headline, group| ad_row(headline, group) }
    list.sort_by { |row| -row[:total] }.first(10)
  end

  def ad_row(headline, group) = { headline: headline, total: group.size, good: group.count { |(_, r)| GOOD.include?(r) } }
end
