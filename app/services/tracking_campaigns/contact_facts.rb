# frozen_string_literal: true

# Campaña con IA — los datos de CADA contacto que usan Reactivar y Recordar (en la plática, en las variables de la
# plantilla y en {{ultima_compra}}, {{vence}}, {{monto}} del paquete y los correos):
#
#   last_purchase       lo último que compró: la cotización ganada más reciente (sus 3 primeros conceptos) o, si no
#                       hay, su contrato más reciente
#   last_purchase_date  cuándo · days_since: hace cuántos días
#   due_what / due_date / due_amount   lo que le vence: el contrato que le recuerda su campaña de Recordar; si no,
#                       su contrato activo más próximo a cobrarse o terminar; si no
#                       tiene, su saldo vencido o por vencer en Cobranza (cartera)
#
#   TrackingCampaigns::ContactFacts.new(contact).values → { 'last_purchase' => …, 'due_date' => '30 de noviembre', … }
class TrackingCampaigns::ContactFacts
  KEYS = %w[last_purchase last_purchase_date days_since due_what due_date due_amount].freeze

  def initialize(contact)
    @contact = contact
  end

  def values
    @values ||= purchase.merge(due).transform_values(&:to_s).compact_blank
  rescue StandardError => e
    Rails.logger.warn("[ContactFacts] contacto #{@contact&.id}: #{e.class}: #{e.message}")
    {}
  end

  LABELS = { 'last_purchase' => 'Lo último que compró', 'last_purchase_date' => 'Cuándo', 'days_since' => 'Hace cuántos días',
             'due_what' => 'Lo que le vence', 'due_date' => 'Fecha', 'due_amount' => 'Monto' }.freeze

  def lines = KEYS.filter_map { |k| "- #{LABELS[k]}: #{values[k]}" if values[k].present? }

  private

  def account = @contact.account

  def purchase
    quote = Quote.where(account_id: @contact.account_id, contact_id: @contact.id, status: :won).order(updated_at: :desc).first
    return quote_purchase(quote) if quote

    contract = Contract.where(account_id: @contact.account_id, contact_id: @contact.id).order(starts_on: :desc).first
    contract ? dated(contract.title, contract.last_paid_on || contract.starts_on) : {}
  end

  def quote_purchase(quote)
    items = quote.items.limit(3).pluck(:description).map { |d| d.to_s.squish.first(60) }
    dated(items.join(', ').presence || "Cotización #{quote.try(:folio) || quote.id}", quote.updated_at.to_date)
  end

  def dated(what, date)
    { 'last_purchase' => what, 'last_purchase_date' => date && date_text(date),
      'days_since' => date && (Date.current - date.to_date).to_i }
  end

  def due
    linked = campaign_contract
    return contract_due(linked) if linked

    contract = Contract.where(account_id: @contact.account_id, contact_id: @contact.id, status: :active)
                       .where('next_charge_on IS NOT NULL OR ends_on IS NOT NULL')
                       .order(Arel.sql('LEAST(COALESCE(next_charge_on, ends_on), COALESCE(ends_on, next_charge_on))')).first
    return contract_due(contract) if contract

    receivables_due
  end

  # Recordar: el contrato que su campaña le recuerda (TrackingCampaigns::RenewEnroll), si sigue activo.
  def campaign_contract
    tracking = ContactTracking.where(account_id: @contact.account_id, contact_id: @contact.id).where.not(contract_id: nil)
                              .order(created_at: :desc).first
    contract = tracking&.contract
    contract if contract&.active?
  end

  def contract_due(contract)
    date = [contract.next_charge_on, contract.ends_on].compact.min
    { 'due_what' => contract.title, 'due_date' => date_text(date),
      'due_amount' => money(contract.price * contract.quantity, contract.currency) }
  end

  def receivables_due
    customer_ids = ReceivableCustomer.where(account_id: @contact.account_id, contact_id: @contact.id).select(:id)
    open = Receivable.where(account_id: @contact.account_id, receivable_customer_id: customer_ids, status: 'open').where('balance > 0')
    return {} unless open.exists?

    { 'due_what' => "Saldo de #{open.count} factura(s)", 'due_date' => date_text(open.minimum(:due_on)),
      'due_amount' => money(open.sum(:balance), open.pick(:currency)) }
  end

  MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

  # «15 de diciembre de 2026» (la cuenta no trae formatos de fecha en español).
  def date_text(date)
    date = date.to_date
    "#{date.day} de #{MONTHS[date.month - 1]} de #{date.year}"
  end

  def money(amount, currency)
    "$#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', amount.to_d))} #{currency.presence || 'MXN'}"
  end
end
