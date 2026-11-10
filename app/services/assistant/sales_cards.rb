# frozen_string_literal: true

# Asistente (Dali) — D5a: la tarjeta de datos que acompaña una respuesta de ventas.
# Cifras crudas (el panel las formatea con la moneda); enlaces a la pantalla.
#   { title:, tiles: [{ label:, kind: money|percent|number, value:, currency: }],
#     table: { columns: [{ label:, kind: }], rows: [[{ value:, currency:, path: }]] },
#     link: { label:, path: } }
module Assistant::SalesCards
  module_function

  def for(name, data, account:)
    base = "/app/accounts/#{account.id}"
    card = public_send(name, data, base)
    card&.compact
  rescue StandardError => e
    Rails.logger.error("[Assistant] tarjeta #{name}: #{e.message}")
    nil
  end

  def t(key, **params) = I18n.t("assistant.sales.cards.#{key}", **params)

  def sales_overview(data, base)
    currency, won = data[:won].first || [main_budget(data)&.dig(:currency) || 'MXN', 0]
    budget = main_budget(data)
    tiles = [{ label: t('won'), kind: 'money', value: won, currency: currency }]
    tiles += budget_tiles(budget) if budget
    tiles << { label: t('vs_previous'), kind: 'percent', value: change(won, data.dig(:compare, :won, currency)) }
    tiles << { label: t('win_rate'), kind: 'percent', value: data[:win_rate] }
    { title: t('overview_title', from: data.dig(:period, :from), to: data.dig(:period, :to), who: data[:seller] || t('everyone')),
      tiles: tiles.reject { |tile| tile[:value].nil? }, link: { label: t('open_budget'), path: "#{base}/tickets/budget" } }
  end

  def budget_progress(data, base)
    rows = data[:sellers].map do |s|
      [{ value: s[:name] || t('no_seller') }, money(s[:budget], data[:currency]), money(s[:actual], data[:currency]),
       { value: s[:percent], kind: 'percent' }]
    end
    { title: t('budget_title', from: data.dig(:period, :from), to: data.dig(:period, :to)),
      table: { columns: cols(%w[seller budget won progress], %w[text money money percent]), rows: rows },
      link: { label: t('open_budget'), path: "#{base}/tickets/budget" } }
  end

  def pipeline_health(data, base)
    value = data[:open_value].first || {}
    { title: t('pipeline_title', who: data[:seller] || t('everyone')),
      tiles: [{ label: t('open'), kind: 'money', value: value[:amount], currency: value[:currency] },
              { label: t('weighted'), kind: 'money', value: value[:weighted], currency: value[:currency] },
              { label: t('committed_overdue'), kind: 'number', value: data[:committed_overdue].size },
              { label: t('stale', days: data.dig(:stale, :threshold_days)), kind: 'number', value: data.dig(:stale, :count) }]
        .reject { |tile| tile[:value].nil? },
      table: deals_table(data[:committed_overdue] + data[:close_overdue], base),
      link: { label: t('open_pipeline'), path: "#{base}/tickets/commercial/metrics" } }
  end

  def sales_breakdown(data, base)
    rows = data[:rows].map do |r|
      [{ value: r[:name] }, money(r[:won_total], r[:currency]), { value: r[:deals], kind: 'number' },
       r.key?(:win_rate) ? { value: r[:win_rate], kind: 'percent' } : money(r[:avg_ticket], r[:currency])]
    end
    last = data[:dimension] == 'seller' ? %w[win_rate percent] : %w[avg_ticket money]
    { title: t("breakdown_#{data[:dimension]}", from: data.dig(:period, :from), to: data.dig(:period, :to)),
      table: { columns: cols(['name', 'won', 'deals', last[0]], ['text', 'money', 'number', last[1]]), rows: rows },
      link: { label: t('open_budget'), path: "#{base}/tickets/budget" } }
  end

  def deal_list(data, base)
    { title: t("deals_#{data[:filter]}", default: t('deals_title')), table: deals_table(data[:deals], base) }
  end

  def deals_table(deals, base)
    return nil if deals.blank?

    rows = deals.first(Sales::Insights::LIMIT).map do |d|
      [{ value: d[:folio], path: "#{base}/tickets/#{d[:id]}" }, { value: d[:client] || d[:title] },
       money(d[:amount], d[:currency]), { value: d[:expected_close_at] }]
    end
    { columns: cols(%w[folio client amount close], %w[text text money text]), rows: rows }
  end

  def main_budget(data)
    data.dig(:budget, :by_currency)&.first
  end

  def budget_tiles(budget)
    [{ label: t('budget'), kind: 'money', value: budget[:budget], currency: budget[:currency] },
     { label: t('progress'), kind: 'percent', value: budget[:percent] }]
  end

  def change(now, before)
    return nil if before.nil? || before.zero?

    ((now - before) * 100.0 / before).round(1)
  end

  def money(value, currency) = { value: value, currency: currency, kind: 'money' }

  def cols(keys, kinds) = keys.zip(kinds).map { |key, kind| { label: t("col_#{key}"), kind: kind } }
end
