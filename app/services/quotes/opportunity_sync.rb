# Plan-Catalogo-Cotizaciones V1 — mantiene de acuerdo una cotización y su
# oportunidad. Regla: la oportunidad manda sobre el resultado final y una
# cotización ganada siempre la gana.
#
# Cotización → oportunidad (`from_quote`):
#   · ganada: la oportunidad se gana con el monto de la cotización; las demás
#     cotizaciones vivas pasan a canceladas («Se aceptó COT-x»).
#   · con UNA sola cotización la oportunidad es su espejo (perdida, cancelada,
#     pospuesta, reanudada).
#   · con varias: si ya no queda ninguna viva, se devuelve `:all_closed` para que
#     la pantalla pregunte si se cierra la oportunidad (no se hace sola).
# Oportunidad → cotizaciones (`from_opportunity`): ganada, perdida, cancelada,
# pospuesta o reanudada se refleja en las cotizaciones vivas.
class Quotes::OpportunitySync
  NOTE_ACCEPTED = 'Se aceptó %<folio>s'.freeze

  def self.syncing?
    Thread.current[:quotes_syncing].present?
  end

  def self.without_loop
    previous = Thread.current[:quotes_syncing]
    Thread.current[:quotes_syncing] = true
    yield
  ensure
    Thread.current[:quotes_syncing] = previous
  end

  # Devuelve nil o :all_closed (la pantalla pregunta qué hacer con la oportunidad).
  def self.from_quote(quote, actor: nil)
    return if syncing? || quote.opportunity.nil?

    without_loop { new(quote.opportunity, actor).quote_changed(quote) }
  end

  def self.from_opportunity(opportunity, event, actor: nil, accepted_quote_id: nil)
    return if syncing?

    without_loop { new(opportunity, actor).opportunity_changed(event, accepted_quote_id) }
  end

  def initialize(opportunity, actor)
    @opportunity = opportunity
    @actor = actor
  end

  def quote_changed(quote)
    single = @opportunity.quotes.count == 1
    return win_with(quote) if quote.won?
    return mirror(quote) if single

    siblings = @opportunity.quotes.live.where.not(id: quote.id)
    :all_closed if %w[lost cancelled].include?(quote.status) && siblings.none? && opportunity_open?
  end

  def opportunity_changed(event, accepted_quote_id)
    live = @opportunity.quotes.live
    case event.to_s
    when 'won' then accept_on_win(live, accepted_quote_id)
    when 'lost', 'cancelled' then close_all(live, event.to_s)
    when 'postponed' then postpone_all(live.open_quotes)
    when 'resumed' then @opportunity.quotes.postponed.find_each { |q| q.update!(status: :sent, postponed_until: nil) }
    end
  end

  private

  def opportunity_open?
    !@opportunity.closed? && !@opportunity.cancelled?
  end

  def win_with(quote)
    cancel_others(quote)
    return unless opportunity_open?

    @opportunity.resume!(actor: @actor) if @opportunity.postponed?
    @opportunity.update!(amount: quote.total, currency: quote.currency)
    @opportunity.close_with_outcome!(:won, actor: @actor, reason_id: quote.outcome_reason_id, note: quote.outcome_note)
    nil
  end

  def mirror(quote)
    if %w[lost cancelled].include?(quote.status)
      close_opportunity(quote.status, quote) if opportunity_open?
    elsif quote.postponed?
      postpone_opportunity(quote) if opportunity_open? && !@opportunity.postponed?
    elsif @opportunity.postponed?
      @opportunity.resume!(actor: @actor)
    end
    nil
  end

  def close_opportunity(status, quote)
    @opportunity.resume!(actor: @actor) if @opportunity.postponed?
    @opportunity.close_with_outcome!(status.to_sym, actor: @actor, reason_id: quote.outcome_reason_id, note: quote.outcome_note)
  end

  def postpone_opportunity(quote)
    @opportunity.postpone!(until_date: quote.postponed_until || 2.weeks.from_now.to_date, actor: @actor,
                           reason_id: quote.outcome_reason_id)
  end

  def cancel_others(quote)
    @opportunity.quotes.live.where.not(id: quote.id).find_each do |other|
      other.update!(status: :cancelled, decided_at: Time.current, outcome_note: format(NOTE_ACCEPTED, folio: quote.folio))
    end
  end

  def accept_on_win(live, accepted_quote_id)
    chosen = live.find_by(id: accepted_quote_id) if accepted_quote_id.present?
    chosen ||= live.order(Arel.sql('sent_at DESC NULLS LAST, id DESC')).first
    return unless chosen

    chosen.update!(status: :won, decided_at: Time.current)
    cancel_others(chosen)
    Quotes::ApplyToOrigin.call(chosen)
  end

  def close_all(live, status)
    live.find_each do |quote|
      quote.update!(status: status, decided_at: Time.current, outcome_reason_id: @opportunity.outcome_reason_id,
                    outcome_note: @opportunity.outcome_note)
    end
  end

  def postpone_all(open)
    open.find_each { |quote| quote.update!(status: :postponed, postponed_until: @opportunity.postponed_until) }
  end
end
