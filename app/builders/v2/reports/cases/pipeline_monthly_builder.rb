# frozen_string_literal: true

# @tickets_cases — Plan-Metricas-Comercial M3 («Mes a mes», a pedido con «Calcular»).
#
# Ventana propia (`span`): últimos 12 meses con el actual (por defecto), este año
# (enero al mes actual) o el año pasado (ene–dic). Con los filtros de tipo,
# vendedor, equipo y moneda — el período de la página NO aplica. Por mes:
#   - ganadas y perdidas por `outcome_at` (cuándo se decidieron), con su monto;
#   - tasa de cierre del mes (ganadas / ganadas + perdidas);
#   - nuevas: oportunidades creadas ese mes (si bajan, en meses bajan las ventas).
# Montos por moneda, como el resto del reporte.
class V2::Reports::Cases::PipelineMonthlyBuilder < V2::Reports::Cases::PipelineBuilder
  MONTHS = 12
  SPANS = %w[last_12 this_year last_year].freeze
  MONTH_SQL = "TO_CHAR(DATE_TRUNC('month', %s), 'YYYY-MM')"

  def build
    decided = decided_by_month
    created = created_by_month
    { span: SPANS.include?(params[:span]) ? params[:span] : 'last_12',
      months: month_keys.map { |m| month_row(m, decided[m] || [], created[m] || 0) } }
  end

  private

  def window
    @window ||= begin
      today = Time.zone.today
      first, last = case params[:span]
                    when 'this_year' then [today.beginning_of_year, today]
                    when 'last_year' then [today.prev_year.beginning_of_year, today.prev_year.end_of_year]
                    else [(today << (MONTHS - 1)).beginning_of_month, today]
                    end
      first.beginning_of_day..last.end_of_day
    end
  end

  def month_keys
    first = window.begin.to_date
    last = window.end.to_date
    count = ((last.year * 12) + last.month) - ((first.year * 12) + first.month) + 1
    (0...count).map { |i| (first >> i).strftime('%Y-%m') }
  end

  # mes → [[outcome, currency, count, amount], ...]
  def decided_by_month
    month = format(MONTH_SQL, 'case_tickets.outcome_at')
    commercial_tickets.where(outcome: %i[won lost], outcome_at: window)
                      .group(Arel.sql(month), 'case_tickets.outcome', 'case_tickets.currency')
                      .pluck(Arel.sql(month), 'case_tickets.outcome', 'case_tickets.currency',
                             Arel.sql('COUNT(*)'), Arel.sql(AMOUNT))
                      .group_by(&:first).transform_values { |rows| rows.map { |r| [outcome_key(r[1]), *r[2..]] } }
  end

  def created_by_month
    month = format(MONTH_SQL, 'case_tickets.created_at')
    commercial_tickets.where(created_at: window).group(Arel.sql(month)).count
  end

  def month_row(month, rows, created)
    won = rows.select { |r| r[0] == 'won' }
    lost = rows.select { |r| r[0] == 'lost' }
    won_count = won.sum { |r| r[2] }
    lost_count = lost.sum { |r| r[2] }
    { month: month, created_count: created, won_count: won_count, lost_count: lost_count,
      won_value: won.map { |r| money(r[1], amount: r[3], count: r[2]) },
      lost_value: lost.map { |r| money(r[1], amount: r[3], count: r[2]) },
      win_rate: rate(won_count, won_count + lost_count) }
  end
end
