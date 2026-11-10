# frozen_string_literal: true

# Asistente (Dali) — D5a: preguntas de ventas («¿cómo vamos?», «¿quién va atrás?», «¿qué
# cierro esta semana?»). Las cifras salen de Sales::Insights (sin IVA, por trato, con los
# permisos de quien pregunta); Dali solo las explica. Cada función devuelve además una
# tarjeta de datos para el panel (Assistant::SalesCards) y preguntas para seguir.
# Se incluye en Assistant::Tools.
module Assistant::SalesTools
  SALES_TOOLS = %w[sales_overview budget_progress pipeline_health sales_breakdown deal_list].freeze

  def sales_tool(name, args)
    data = public_send("tool_#{name}", args)
    { result: data, card: Assistant::SalesCards.for(name, data, account: @account),
      suggestions: I18n.t("assistant.sales.suggestions.#{name}", default: []), analysis: true }
  rescue Sales::Insights::Denied, ArgumentError => e
    { result: { error: e.message } }
  end

  def tool_sales_overview(args)
    insights.overview(compare: args['compare'].presence || 'previous', seller_id: seller_id(args), **period(args))
  end

  def tool_budget_progress(args)
    insights.budget_progress(seller_id: seller_id(args), currency: args['currency'], **period(args))
  end

  def tool_pipeline_health(args)
    insights.pipeline_health(seller_id: seller_id(args))
  end

  def tool_sales_breakdown(args)
    insights.breakdown(dimension: args['dimension'] == 'client' ? 'client' : 'seller', metric: args['metric'].presence || 'won_value',
                       top: args['top'].presence || Sales::Insights::LIMIT, **period(args))
  end

  def tool_deal_list(args)
    filter = Sales::Insights::DEAL_FILTERS.include?(args['filter']) ? args['filter'] : 'closing_this_month'
    insights.deals(filter: filter, seller_id: seller_id(args), min_amount: args['min_amount'])
  end

  private

  def insights
    @insights ||= Sales::Insights.new(account: @account, user: @user, grant: @grant, zone: @zone)
  end

  def period(args)
    { period: Sales::Period::NAMES.include?(args['period']) ? args['period'] : 'this_month',
      from: args['from'].presence, to: args['to'].presence }
  end

  # El vendedor por nombre («¿cómo va Luis?»); con «solo lo suyo» Insights lo ignora.
  def seller_id(args)
    name = args['seller'].to_s.strip
    return nil if name.blank?

    user = @account.users.where('users.name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(name)}%").first
    raise ArgumentError, "No encontré al vendedor «#{name}»." unless user

    user.id
  end
end
