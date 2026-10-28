# CrmZeus O1 — JSON de los catálogos de organizaciones.
module Crm::CatalogJson
  module_function

  def lookup(item)
    item.slice(:id, :kind, :name, :is_default, :position, :active)
  end

  def seller(item)
    item.slice(:id, :name, :notes, :user_id, :is_default, :active).merge(user_name: item.user&.name)
  end

  def payment_term(item)
    item.slice(:id, :name, :early_payment_days, :is_default, :active).merge(
      early_payment_discount_percent: item.early_payment_discount_percent.to_f, credit_days: item.credit_days,
      installments: item.installments.map { |i| { id: i.id, days: i.days, percent: i.percent.to_f } }
    )
  end

  def currency(item)
    item.slice(:id, :name, :iso_code, :symbol, :amount_in_words, :is_local, :is_default, :active)
        .merge(fixed_exchange_rate: item.fixed_exchange_rate&.to_f)
  end

  def country(item)
    item.slice(:id, :name, :abbreviation, :iso_code, :is_default)
        .merge(states: item.states.sort_by(&:name).map { |state| state.slice(:id, :name, :abbreviation) })
  end

  def state(item)
    item.slice(:id, :name, :abbreviation, :country_id).merge(country_name: item.country&.name)
  end

  def city(item)
    { id: item.id, name: item.name, state_id: item.state_id, full_name: item.full_name }
  end
end
