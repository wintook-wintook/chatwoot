# Dali D5a — consultas de ventas para el asistente. Las CIFRAS las calcula el sistema
# (Sales::Actuals, Sales::BudgetReport, el embudo); Dali solo las explica.
#   · Lo ganado es siempre sin IVA y por trato (Sales::Actuals).
#   · Permisos de quien pregunta: sin Ventas, nada; con «solo lo suyo», solo lo suyo
#     (aunque pida a otro vendedor); con «Ver»/«Todo», todo o el vendedor que pida.
# Periodos: this_month, last_month, this_quarter, last_quarter, this_year, last_year,
# o from/to (YYYY-MM-DD). Los montos se agrupan por moneda: nunca se suman distintas.
class Sales::Insights
  include Sales::InsightsDeals

  class Denied < StandardError; end

  DEAL_FILTERS = %w[closing_this_week closing_this_month overdue committed_overdue stale top_open won_recent].freeze
  LIMIT = 8

  def initialize(account:, user:, grant:, zone: Time.zone)
    @account = account
    @user = user
    @grant = grant
    @zone = zone
    raise Denied, 'No tienes acceso a Ventas.' unless grant.allowed?(:sales)
  end

  def own_only? = @grant.own?(:sales)

  # ── ¿Cómo vamos? ─────────────────────────────────────────────────────────────
  def overview(compare: 'previous', seller_id: nil, **period)
    range = period_range(**period)
    ids = user_ids(seller_id)
    won = won_by_currency(range, ids)
    { period: Sales::Period.label(range), seller: seller_name(ids), won: won, won_deals: deal_count(range, ids),
      compare: compare_block(range, compare, ids), win_rate: win_rate(range, ids), avg_cycle_days: avg_cycle(range, ids),
      budget: budget_block(range, ids, won), open_pipeline: open_pipeline(ids),
      closing_rest_of_period: closing_in(range, ids) }
  end

  # ── Presupuesto: quién va atrás y qué lo cubre ──────────────────────────────────
  def budget_progress(seller_id: nil, currency: nil, **period)
    range = period_range(**period)
    ids = user_ids(seller_id)
    currency = (currency.presence || main_currency).upcase
    report = Sales::BudgetReport.new(account: @account, from: range.begin.to_date.beginning_of_month,
                                     to: range.end.to_date.beginning_of_month, currency: currency, user_ids: ids).build
    sellers = report[:sellers].map { |s| s.slice(:name, :budget, :actual, :percent, :diff, :other_actual).merge(clients: s[:clients].first(5)) }
    { period: Sales::Period.label(range), currency: currency, totals: report[:totals],
      elapsed_percent: Sales::Period.elapsed_percent(range), sellers: sellers,
      can_close_gap: gap_deals(range, ids, currency) }
  end

  # ── Salud del embudo ────────────────────────────────────────────────────────────
  def pipeline_health(seller_id: nil)
    ids = user_ids(seller_id)
    open = open_opportunities(ids)
    { seller: seller_name(ids), open_count: open.count, open_value: money_rows(open), stages: stage_counts(open),
      committed_overdue: deal_rows(open.where.not(committed_at: nil).where(expected_close_at: ...today)),
      close_overdue: deal_rows(open.where(committed_at: nil).where(expected_close_at: ...today)),
      without_close_date: open.where(expected_close_at: nil).count, stale: stale_block(ids) }
  end

  # ── Ranking por vendedor o cliente ─────────────────────────────────────────────
  def breakdown(dimension: 'seller', metric: 'won_value', top: LIMIT, **period)
    range = period_range(**period)
    rows = Sales::Actuals.new(account: @account, range: range, user_ids: user_ids(nil)).rows
    groups = rows.group_by { |r| dimension == 'client' ? client_key(r) : r[:user_id] }
    list = groups.map { |key, items| breakdown_row(dimension, key, items) }
    list = add_win_rates(list, range) if dimension == 'seller'
    sort_key = { 'won_count' => :deals, 'avg_ticket' => :avg_ticket, 'win_rate' => :win_rate }.fetch(metric, :won_total)
    { period: Sales::Period.label(range), dimension: dimension, metric: metric,
      rows: list.sort_by { |r| -(r[sort_key] || 0) }.first(top.to_i.clamp(1, 20)) }
  end

  # ── Lista de tratos para actuar ───────────────────────────────────────────────────
  def deals(filter: 'closing_this_month', seller_id: nil, min_amount: nil)
    ids = user_ids(seller_id)
    scope = filter == 'won_recent' ? won_scope(today.beginning_of_month.in_time_zone..Time.current, ids) : open_opportunities(ids)
    scope = deal_filter(scope, filter, ids)
    scope = scope.where('case_tickets.amount >= ?', min_amount.to_d) if min_amount.present?
    { filter: filter, seller: seller_name(ids), deals: deal_rows(scope) }
  end

  private

  def today = Time.current.in_time_zone(@zone).to_date

  # Con «solo lo suyo» siempre él; si no, el vendedor pedido o todos.
  def user_ids(seller_id)
    return [@user.id] if own_only?
    return nil if seller_id.blank?

    [@account.users.find(seller_id).id]
  end

  def seller_name(ids)
    ids && @account.users.where(id: ids).pick(:name)
  end

  def period_range(period: 'this_month', from: nil, to: nil)
    Sales::Period.range(period, zone: @zone, from: from, to: to)
  end

  def won_by_currency(range, ids)
    Sales::Actuals.new(account: @account, range: range, user_ids: ids).totals_by_currency.transform_values { |v| v.to_f.round(2) }
  end

  def deal_count(range, ids)
    Sales::Actuals.new(account: @account, range: range, user_ids: ids).rows.size
  end

  def compare_block(range, compare, ids)
    previous = Sales::Period.previous(range, compare)
    { against: compare.to_s == 'last_year' ? 'mismo periodo del año pasado' : 'periodo anterior',
      period: Sales::Period.label(previous),
      won: won_by_currency(previous, ids), win_rate: win_rate(previous, ids) }
  end

  def commercial
    @account.case_tickets.commercial
  end

  def scoped(scope, ids)
    ids ? scope.where(assignee_id: ids) : scope
  end

  def win_rate(range, ids)
    decided = scoped(commercial.where(outcome_at: range), ids)
    won = decided.outcome_won.count
    total = won + decided.outcome_lost.count
    total.zero? ? nil : ((won * 100.0) / total).round(1)
  end

  def avg_cycle(range, ids)
    rows = scoped(commercial.outcome_won.where(outcome_at: range), ids).pluck(:created_at, :outcome_at)
    rows.empty? ? nil : (rows.sum { |c, o| (o - c) / 1.day } / rows.size).round(1)
  end

  def main_currency
    @account.sales_budget_lines.pick(:currency) ||
      commercial.where.not(currency: nil).group(:currency).count.max_by(&:last)&.first || 'MXN'
  end

  # Meta del periodo contra lo ganado, por moneda, y cuánto del periodo ya pasó.
  def budget_block(range, ids, won)
    lines = @account.sales_budget_lines.seller_only.where(period: range.begin.to_date.beginning_of_month..range.end.to_date)
    lines = lines.where(user_id: ids) if ids
    budget = lines.group(:currency).sum(:amount)
    return nil if budget.empty?

    { elapsed_percent: Sales::Period.elapsed_percent(range),
      by_currency: budget.map { |currency, amount| budget_row(currency, amount.to_f, won[currency].to_f) } }
  end

  def budget_row(currency, budget, actual)
    { currency: currency, budget: budget, actual: actual, percent: budget.positive? ? (actual * 100 / budget).round(1) : nil,
      missing: [budget - actual, 0].max.round(2) }
  end

  def open_opportunities(ids)
    scoped(@grant.case_tickets(commercial).where(status: CaseTicket::PENDING_STATUSES), ids)
  end

  def won_scope(range, ids)
    scoped(@grant.case_tickets(commercial).outcome_won.where(outcome_at: range), ids)
  end

  def open_pipeline(ids)
    open = open_opportunities(ids)
    { count: open.count, value: money_rows(open) }
  end

  def closing_in(range, ids)
    rest = [Time.current, range.begin].max.to_date..range.end.to_date
    scope = open_opportunities(ids).where(expected_close_at: rest)
    { count: scope.count, value: money_rows(scope), committed: money_rows(scope.where.not(committed_at: nil)) }
  end

  def money_rows(scope)
    scope.where.not(currency: nil).group(:currency)
         .pluck(:currency, Arel.sql('COALESCE(SUM(amount), 0)'), Arel.sql('COALESCE(SUM(amount * COALESCE(probability, 0) / 100.0), 0)'))
         .map { |cur, amount, weighted| { currency: cur, amount: amount.to_f.round(2), weighted: weighted.to_f.round(2) } }
  end

  def stage_counts(scope)
    scope.left_joins(:case_type_column).group('case_type_columns.label').count
  end

  def client_key(row)
    row[:organization_id] ? [:organization, row[:organization_id]] : [:contact, row[:contact_id]]
  end

  def breakdown_row(dimension, key, items)
    total = items.sum { |r| r[:amount] }
    { name: breakdown_name(dimension, key), user_id: (key if dimension == 'seller'),
      currency: items.first[:currency], won_total: total.to_f.round(2), deals: items.size,
      avg_ticket: (total / items.size).to_f.round(2) }
  end

  def breakdown_name(dimension, key)
    return @account.users.where(id: key).pick(:name) || 'Sin vendedor' unless dimension == 'client'

    kind, id = key
    (kind == :organization ? @account.organizations : @account.contacts).where(id: id).pick(:name) || 'Sin cliente'
  end

  def add_win_rates(list, range)
    list.map { |row| row.merge(win_rate: row[:user_id] ? win_rate(range, [row[:user_id]]) : nil) }
  end
end
