# Plan-Catalogo-Cotizaciones V1 — cambia el estado de una cotización (desde la
# pantalla o desde el enlace del cliente) y sincroniza su oportunidad.
#
#   Quotes::StatusService.new(quote, actor: user).apply!('lost', reason_id: 3, note: 'Precio')
#   # => { quote:, prompt: nil | :all_closed }
class Quotes::StatusService
  Error = Class.new(StandardError)

  FROM = {
    'sent' => %w[draft postponed],
    'won' => %w[draft sent postponed],
    'lost' => %w[draft sent postponed],
    'cancelled' => %w[draft sent postponed],
    'postponed' => %w[draft sent],
    'reopen' => %w[lost cancelled]
  }.freeze

  def initialize(quote, actor: nil)
    @quote = quote
    @actor = actor
  end

  # opts: reason_id, note, postponed_until, accepted_by_name, signature
  def apply!(to, **opts)
    to = to.to_s
    raise Error, I18n.t('quotes.errors.transition') unless FROM.fetch(to, []).include?(@quote.status)

    @quote.update!(attributes_for(to, opts))
    prompt = Quotes::OpportunitySync.from_quote(@quote, actor: @actor)
    Quotes::ApplyToOrigin.call(@quote) if @quote.won?
    { quote: @quote, prompt: prompt }
  end

  private

  def attributes_for(to, opts)
    case to
    when 'sent', 'reopen'
      { status: :sent, sent_at: @quote.sent_at || Time.current, postponed_until: nil, decided_at: nil,
        outcome_reason_id: nil, outcome_note: nil }
    when 'postponed'
      { status: :postponed, postponed_until: opts[:postponed_until].presence || 2.weeks.from_now.to_date,
        outcome_reason_id: opts[:reason_id], outcome_note: opts[:note] }
    else
      decided_attributes(to, opts)
    end
  end

  def decided_attributes(to, opts)
    attrs = { status: to, decided_at: Time.current, outcome_reason_id: opts[:reason_id], outcome_note: opts[:note] }
    attrs.merge!(accepted_by_name: opts[:accepted_by_name], accepted_signature: opts[:signature]) if to == 'won'
    attrs.compact
  end
end
