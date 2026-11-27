# frozen_string_literal: true

# Motor 2.0 — «Cómo le va» de los tres agentes listos (últimos DAYS días). Mismo formato para la pantalla:
#   { kind:, days:, total:, rate:, results: { clave => n }, groups: { clave => n }, drop_off: [...], ads: [...] }
#   prospects        Motor2::ProspectMetrics (calificados, con cita, dónde se van, de qué anuncio)
#   customers        por las etiquetas de cómo lo catalogó: qué pidió (groups) y qué se hizo (results); rate = % que
#                    resolvió el agente sin pasarlo
#   campaign_seller  cómo terminaron los que contestaron: le interesó, no le interesó, sin respuesta; rate = % interesados
class Motor2::AgentMetrics
  DAYS = 30
  CUSTOMER_RESULTS = %w[respondida resuelto resuelto-sin-confirmar info-relacionada sin-respuesta caso-levantado canalizada
                        gestion-registrada cotizacion cita cita-agendada objetivo-logrado objetivo-pendiente].freeze
  CUSTOMER_GROUPS = %w[soporte-duda soporte-falla soporte-critico informacion cotizacion demo visita vendedor contratar
                       administrativo otra-area humano].freeze

  def initialize(template)
    @template = template
    @since = DAYS.days.ago
  end

  def call
    case @template.agent_function
    when 'customers' then customers
    when 'campaign_seller' then campaign
    else Motor2::ProspectMetrics.new(@template).call.then { |m| m.merge(kind: 'prospects', rate: m[:conversion]) }
    end
  end

  private

  # Sin las copias de «Prueba real» de las campañas.
  def trackings
    tests = TrackingCampaign.where.not(test_of_id: nil).select(:id)
    ContactTracking.where(tracking_template_id: @template.id).where(created_at: @since..)
                   .where('tracking_campaign_id IS NULL OR tracking_campaign_id NOT IN (?)', tests).includes(:conversation).to_a
  end

  def customers
    labels = trackings.map { |t| Array(t.conversation&.label_list) }
    total = labels.size
    return customers_goal(labels) if goal?

    solved = labels.count { |l| l.intersect?(%w[respondida resuelto]) && !l.intersect?(%w[canalizada caso-levantado]) }
    { kind: 'customers', days: DAYS, total: total, rate: percent(solved, total),
      results: tally(labels, CUSTOMER_RESULTS), groups: tally(labels, CUSTOMER_GROUPS), drop_off: [], ads: [] }
  end

  # Con «¿Qué quieres que logre?» (Motor2::Skills::Goal): % que lo logró (agendó o cotizó).
  def goal? = @template.motor2.to_h.dig('answers', 'goal').to_s.presence_in(%w[appointment quote]).present?

  def customers_goal(labels)
    goal = @template.motor2.to_h.dig('answers', 'goal')
    done = labels.count { |l| l.include?('objetivo-logrado') }
    { kind: "customers_#{goal}", days: DAYS, total: labels.size, rate: percent(done, labels.size),
      results: tally(labels, CUSTOMER_RESULTS), groups: tally(labels, CUSTOMER_GROUPS), drop_off: [], ads: [] }
  end

  def campaign
    rows = trackings.select { |t| t.conversation&.messages&.incoming&.exists? }.map { |t| campaign_result(t) }
    results = rows.tally
    { kind: 'campaign_seller', days: DAYS, total: rows.size, rate: percent(results['interested'].to_i, rows.size),
      results: results, groups: {}, drop_off: [], ads: [] }
  end

  def campaign_result(tracking)
    outcome = tracking.outcome.to_s
    return 'interested' if interested?(tracking, outcome)
    return 'not_interested' if outcome == 'discarded' || tracking.status == 'cancelled'
    return 'no_answer' if tracking.motor2_state.to_h['follow_up_done'] || tracking.status == 'completed'

    tracking.status == 'objective_met' ? 'done' : 'live'
  end

  def interested?(tracking, outcome) = outcome.start_with?('relayed', 'Cita') || %w[interested handed_off].include?(tracking.prospect_stage.to_s)

  def tally(labels, keys) = keys.index_with { |k| labels.count { |l| l.include?(k) } }.select { |_, n| n.positive? }

  def percent(part, total) = total.zero? ? 0 : (part * 100.0 / total).round
end
