# Plan-Organizaciones O5 — Informes › Dashboard de clientes: cuántos prospectos y clientes
# hay, cuántos llegaron en el periodo, la conversión (de los que entraron como prospecto en
# el periodo, cuántos ya son clientes), los días promedio de prospecto a cliente y la
# serie por mes. Sobre las organizaciones que el usuario puede ver.
class Organizations::Metrics
  def initialize(scope:, months: 6, today: Time.zone.today)
    @scope = scope
    @months = months.to_i.clamp(1, 24)
    @today = today
  end

  def as_json
    {
      since: since.to_date, until: @today,
      totals: totals,
      new_prospects: in_period(:became_prospect_at).count,
      new_customers: in_period(:became_customer_at).count,
      conversion_rate: conversion_rate,
      avg_days_to_customer: avg_days_to_customer,
      monthly: monthly
    }
  end

  private

  def since
    @since ||= (@today.beginning_of_month << (@months - 1)).beginning_of_day
  end

  def in_period(column)
    @scope.where(column => since..@today.end_of_day)
  end

  def totals
    stages = @scope.group(:stage).count
    kinds = @scope.group(:kind).count
    Organization.stages.keys.index_with { |key| stages[key] || 0 }
                .merge(Organization.kinds.keys.index_with { |key| kinds[key] || 0 })
  end

  # De los que entraron como prospecto en el periodo, qué porcentaje ya es cliente.
  def conversion_rate
    entered = in_period(:became_prospect_at)
    total = entered.count
    return 0 if total.zero?

    (entered.customer.count * 100.0 / total).round(1)
  end

  def avg_days_to_customer
    seconds = in_period(:became_customer_at).where.not(became_prospect_at: nil)
                                            .average('EXTRACT(EPOCH FROM (became_customer_at - became_prospect_at))')
    seconds ? (seconds.to_f / 1.day).round(1) : nil
  end

  def monthly
    prospects = count_by_month(:became_prospect_at)
    customers = count_by_month(:became_customer_at)
    (0...@months).map do |offset|
      month = (since.to_date >> offset).strftime('%Y-%m')
      { month: month, prospects: prospects[month] || 0, customers: customers[month] || 0 }
    end
  end

  def count_by_month(column)
    in_period(column).group(Arel.sql("TO_CHAR(#{column}, 'YYYY-MM')")).count
  end
end
