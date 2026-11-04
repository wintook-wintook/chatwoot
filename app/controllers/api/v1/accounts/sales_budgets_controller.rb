# frozen_string_literal: true

# ================================================================================
# Presupuesto de ventas — etapa 1: meta mensual por vendedor y por vendedor + cliente.
# GET    /sales_budgets         { year, currency, kind: seller|seller_client, user_id }
# PUT    /sales_budgets/bulk    { year, currency, lines: [{ user_id, organization_id |
#                                 contact_id, period: 'YYYY-MM', amount }] }  0/vacío = borra
# POST   /sales_budgets/copy    { from_year, to_year, currency, percent }  no pisa lo capturado
# DELETE /sales_budgets/client  { year, currency, user_id, organization_id | contact_id }
# GET    /sales_budgets/report  { from: 'YYYY-MM', to: 'YYYY-MM', currency }
#   Meta contra lo logrado (Sales::Actuals) por vendedor y sus clientes.
# Capturar: Ventas en «Todo» (o administrador). Ver el avance: Ventas; con «solo lo
# suyo», solo lo propio.
# ================================================================================
class Api::V1::Accounts::SalesBudgetsController < Api::V1::Accounts::BaseController
  before_action :check_view
  before_action :check_capture, only: %i[bulk copy client]

  def index
    lines = scope_for_kind(budget_lines.in_year(year)).includes(:organization, :contact)
    lines = lines.where(user_id: params[:user_id]) if params[:user_id].present?
    render json: { lines: lines.map { |line| line_json(line) }, can_capture: can_capture?, currencies: currencies }
  end

  def bulk
    SalesBudgetLine.transaction { Array(params[:lines]).each { |attrs| save_line(attrs) } }
    head :no_content
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def copy
    copied = copy_year
    render json: { copied: copied }
  end

  def client
    lines = budget_lines.in_year(year).where(user_id: params[:user_id])
    lines = params[:organization_id].present? ? lines.where(organization_id: params[:organization_id]) : lines.where(contact_id: params[:contact_id])
    lines.where.not(organization_id: nil).or(lines.where.not(contact_id: nil)).delete_all
    head :no_content
  end

  def report
    render json: Sales::BudgetReport.new(account: Current.account, from: month(params[:from]), to: month(params[:to]),
                                         currency: currency, user_ids: own_only? ? [current_user.id] : nil).build
                                    .merge(can_capture: can_capture?, currencies: currencies)
  end

  private

  def check_view
    render_access_denied unless access_grant.allowed?(:sales)
  end

  def check_capture
    render_access_denied unless can_capture?
  end

  def can_capture?
    access_grant.level(:sales) == 'all'
  end

  def own_only?
    access_grant.own?(:sales)
  end

  def budget_lines
    scope = Current.account.sales_budget_lines.without_products.where(currency: currency)
    own_only? ? scope.where(user_id: current_user.id) : scope
  end

  def scope_for_kind(scope)
    params[:kind] == 'seller_client' ? scope.seller_client : scope.seller_only
  end

  def year
    (params[:year].presence || Time.zone.today.year).to_i
  end

  def currency
    params[:currency].to_s.upcase.presence || 'MXN'
  end

  def month(value)
    value.present? ? SalesBudgetLine.month(value) : Time.zone.today.beginning_of_month
  end

  def currencies
    (['MXN'] + Current.account.sales_budget_lines.distinct.pluck(:currency)).uniq.sort
  end

  def save_line(attrs)
    attrs = attrs.permit(:user_id, :organization_id, :contact_id, :period, :amount)
    line = Current.account.sales_budget_lines.find_or_initialize_by(dimensions(attrs).merge(currency: currency))
    amount = attrs[:amount].to_s.strip
    return line.destroy if amount.blank? || amount.to_d.zero?

    line.update!(amount: amount.to_d, created_by: line.created_by || current_user)
  end

  # Solo vendedores, organizaciones y contactos de la cuenta.
  def dimensions(attrs)
    user = Current.account.users.find(attrs[:user_id])
    organization = Current.account.organizations.find(attrs[:organization_id]) if attrs[:organization_id].present?
    contact = Current.account.contacts.find(attrs[:contact_id]) if attrs[:contact_id].present? && organization.nil?
    { period: SalesBudgetLine.month(attrs[:period]), user_id: user.id, organization_id: organization&.id,
      contact_id: contact&.id, product_line_id: nil, catalog_item_id: nil }
  end

  # Copia las metas de un año a otro con ±%; lo ya capturado en el destino se respeta.
  def copy_year
    factor = 1 + (params[:percent].to_d / 100)
    target = params[:to_year].to_i
    budget_lines.in_year(params[:from_year].to_i).where.not(user_id: nil).find_each.count do |line|
      copy_line(line, target, factor)
    end
  end

  def copy_line(line, target, factor)
    attrs = line.slice(:user_id, :organization_id, :contact_id, :product_line_id, :catalog_item_id, :currency)
                .merge(period: line.period.change(year: target))
    return false if Current.account.sales_budget_lines.exists?(attrs)

    Current.account.sales_budget_lines.create!(attrs.merge(amount: (line.amount * factor).round(2), created_by: current_user))
  end

  def line_json(line)
    client = line.organization || line.contact
    { id: line.id, period: line.period.strftime('%Y-%m'), user_id: line.user_id, organization_id: line.organization_id,
      contact_id: line.contact_id, client_name: client&.name, amount: line.amount.to_f }
  end
end
