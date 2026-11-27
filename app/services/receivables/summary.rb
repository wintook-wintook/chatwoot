# frozen_string_literal: true

# Cobranza — lo que debe un cliente, para el agente («Resumen de saldo pendiente») y para las pantallas.
#   s = Receivables::Summary.new(customer)
#   s.invoices → [{ folio:, due_on:, balance:, currency:, days: }]  (las cobrables: abiertas, sin aclaración ni «ya pagué»)
#   s.overdue? · s.total · s.overdue_total · s.stage
#   s.text     → el resumen tal cual se le manda al cliente (montos y fechas salen de la cartera, no del modelo)
#   Receivables::Summary.customer_for(contact) → el cliente de la cartera de ese contacto (o de su organización)
class Receivables::Summary
  STAGES = %w[preventive due overdue_30 overdue_60 overdue_plus].freeze

  def self.customer_for(contact)
    return nil unless contact

    scope = ReceivableCustomer.where(account_id: contact.account_id, link_status: 'linked')
    scope.find_by(contact_id: contact.id) || (contact.organization_id && scope.find_by(organization_id: contact.organization_id))
  end

  def self.money(amount, currency = 'MXN')
    whole, cents = format('%.2f', amount.to_f).split('.')
    "$#{whole.reverse.scan(/\d{1,3}/).join(',').reverse.prepend(whole.start_with?('-') ? '-' : '')}.#{cents} #{currency}"
  end

  def initialize(customer, today: Date.current)
    @customer = customer
    @today = today
  end

  def invoices
    @invoices ||= @customer.receivables.collectable.order(:due_on).map do |r|
      { folio: r.folio, due_on: r.due_on, balance: r.balance.to_f, currency: r.currency, days: (@today - r.due_on).to_i }
    end
  end

  def total = invoices.sum { |i| i[:balance] }

  def overdue = invoices.select { |i| i[:days].positive? }

  def overdue? = overdue.any?

  def overdue_total = overdue.sum { |i| i[:balance] }

  def currency = invoices.first&.dig(:currency) || 'MXN'

  def oldest_days = overdue.pluck(:days).max.to_i

  # En qué etapa va: antes de vencer, 1–15 días, 16–30, 31–60 o más de 60.
  def stage
    days = oldest_days
    return 'preventive' if days <= 0
    return 'due' if days <= 15
    return 'overdue_30' if days <= 30

    days <= 60 ? 'overdue_60' : 'overdue_plus'
  end

  def text
    return "#{@customer.name}: no tiene saldo pendiente." if invoices.empty?

    lines = invoices.map { |i| "• Factura #{i[:folio]} · #{due_text(i)} · #{self.class.money(i[:balance], i[:currency])}" }
    total_line = "Total: #{self.class.money(total, currency)}"
    total_line += " (vencido: #{self.class.money(overdue_total, currency)})" if overdue? && overdue_total < total
    ["Resumen de saldo pendiente — #{@customer.name}", *lines, total_line].join("\n")
  end

  # Para las plantillas de WhatsApp: {{cobranza_saldo}}, {{cobranza_vencido}}, {{cobranza_facturas}}, {{cobranza_dias}},
  # {{cobranza_vence}} (atributos del contacto que lee Whatsapp::TemplateVariableResolver).
  def template_attributes
    next_due = invoices.reject { |i| i[:days].positive? }.min_by { |i| i[:due_on] }
    { 'cobranza_saldo' => self.class.money(total, currency), 'cobranza_vencido' => self.class.money(overdue_total, currency),
      'cobranza_facturas' => invoices.size.to_s, 'cobranza_dias' => oldest_days.to_s,
      'cobranza_vence' => next_due ? I18n.l(next_due[:due_on], format: '%d/%m/%Y') : '' }
  end

  private

  def due_text(invoice)
    date = I18n.l(invoice[:due_on], format: '%d/%m/%Y')
    return "vence el #{date}" if invoice[:days] <= 0

    "venció el #{date} (#{invoice[:days]} días)"
  end
end
