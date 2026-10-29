# Plan-Catalogo-Cotizaciones V1 — cifras de las cotizaciones (las que el rol deja
# ver): enviadas vivas, % de aceptación y tiempo de respuesta (últimos 90 días),
# monto en juego por moneda, vencidas y lo mismo por vendedor.
class Quotes::Summary
  WINDOW = 90.days

  def initialize(scope)
    @scope = scope
  end

  def build
    decided = @scope.where(status: %w[won lost], decided_at: WINDOW.ago..)
    {
      sent: @scope.sent.count,
      expired: @scope.expired.count,
      acceptance_rate: rate(decided),
      avg_response_days: avg_days(decided.where.not(sent_at: nil)),
      in_play: amounts(@scope.where(status: %w[draft sent])),
      won_amounts: amounts(@scope.won.where(decided_at: WINDOW.ago..)),
      by_assignee: by_assignee(decided)
    }
  end

  private

  def rate(decided)
    total = decided.count
    total.zero? ? nil : ((decided.won.count.to_f / total) * 100).round
  end

  def avg_days(rows)
    values = rows.pluck(:sent_at, :decided_at).map { |sent, decided| (decided - sent) / 1.day }
    values.empty? ? nil : (values.sum / values.size).round(1)
  end

  def amounts(rows)
    rows.group(:currency).sum(:total).map { |currency, total| { currency: currency, amount: total.to_f } }
  end

  def by_assignee(decided)
    sent = @scope.where(status: %w[sent won lost postponed]).group(:assignee_id).count
    won = decided.won.group(:assignee_id).count
    lost = decided.lost.group(:assignee_id).count
    names = User.where(id: sent.keys.compact).pluck(:id, :name).to_h
    sent.keys.compact.map { |id| assignee_row(id, names[id], sent[id], won[id].to_i, lost[id].to_i) }
  end

  def assignee_row(id, name, quotes, won, lost)
    closed = won + lost
    { assignee_id: id, name: name, quotes: quotes, won: won,
      acceptance_rate: closed.zero? ? nil : ((won.to_f / closed) * 100).round }
  end
end
