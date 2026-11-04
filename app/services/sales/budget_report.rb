# Presupuesto de ventas — avance de un rango de meses en una moneda:
#   · por vendedor: su meta global (renglones solo con vendedor) contra todo lo que
#     logró (Sales::Actuals);
#   · dentro, sus clientes con meta (vendedor + organización/contacto) contra lo que
#     les vendió, y «otros clientes» = lo logrado con clientes sin meta;
#   · por mes: la meta y lo logrado del total, para la gráfica.
# Entra quien tenga meta o ventas en el rango (las ventas sin vendedor van aparte).
class Sales::BudgetReport
  def initialize(account:, from:, to:, currency:, user_ids: nil)
    @account = account
    @from = from
    @to = [to, from].max
    @currency = currency
    @user_ids = user_ids
  end

  def build
    { from: @from.strftime('%Y-%m'), to: @to.strftime('%Y-%m'), currency: @currency,
      totals: totals, months: months, sellers: sellers }
  end

  private

  def lines
    @lines ||= begin
      scope = @account.sales_budget_lines.without_products.where(currency: @currency, period: @from..@to).where.not(user_id: nil)
      scope = scope.where(user_id: @user_ids) if @user_ids
      scope.includes(:organization, :contact).to_a
    end
  end

  def actuals
    @actuals ||= Sales::Actuals.new(account: @account, from: @from, to: @to, currency: @currency, user_ids: @user_ids).rows
  end

  def seller_lines
    lines.select { |line| line.organization_id.nil? && line.contact_id.nil? }
  end

  def client_lines
    lines.reject { |line| line.organization_id.nil? && line.contact_id.nil? }
  end

  def totals
    figures(seller_lines.sum(&:amount), actuals.sum { |row| row[:amount] })
  end

  def months
    periods.map do |period|
      { period: period.strftime('%Y-%m'),
        budget: seller_lines.select { |l| l.period == period }.sum(&:amount).to_f,
        actual: actuals.select { |r| r[:period] == period }.sum { |r| r[:amount] }.to_f }
    end
  end

  def periods
    list = []
    month = @from
    while month <= @to
      list << month
      month = month.next_month
    end
    list
  end

  def sellers
    ids = (lines.map(&:user_id) + actuals.pluck(:user_id)).uniq
    names = @account.users.where(id: ids.compact).pluck(:id, :name).to_h
    ids.map { |id| seller(id, names[id]) }.sort_by { |row| [row[:user_id].nil? ? 1 : 0, -row[:budget], -row[:actual]] }
  end

  def seller(user_id, name)
    rows = actuals.select { |row| row[:user_id] == user_id }
    clients = clients_of(user_id, rows)
    figures(seller_lines.select { |l| l.user_id == user_id }.sum(&:amount), rows.sum { |row| row[:amount] })
      .merge(user_id: user_id, name: name, clients: clients,
             other_actual: (rows.sum { |row| row[:amount] } - clients.sum { |c| c[:actual] }).to_f)
  end

  def clients_of(user_id, rows)
    groups = client_lines.select { |l| l.user_id == user_id }.group_by { |l| [l.organization_id, l.contact_id] }
    list = groups.map { |(organization_id, contact_id), group| client(group, rows, organization_id, contact_id) }
    list.sort_by { |row| -row[:budget] }
  end

  def client(group, rows, organization_id, contact_id)
    sold = rows.select { |row| client_match?(row, organization_id, contact_id) }.sum { |row| row[:amount] }
    record = group.first.organization || group.first.contact
    figures(group.sum(&:amount), sold).merge(organization_id: organization_id, contact_id: contact_id, name: record&.name)
  end

  # Meta por organización: todo lo de esa organización. Por contacto: lo de ese contacto.
  def client_match?(row, organization_id, contact_id)
    organization_id ? row[:organization_id] == organization_id : row[:contact_id] == contact_id
  end

  def figures(budget, actual)
    { budget: budget.to_f, actual: actual.to_f, diff: (actual - budget).to_f,
      percent: budget.positive? ? ((actual / budget) * 100).round(1).to_f : nil }
  end
end
