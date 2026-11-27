# frozen_string_literal: true

# Cobranza — una fila de la cartera en el formato único (el de la plantilla). Lo usan el Excel/CSV
# (Receivables::Spreadsheet) y, después, cada integración con un sistema administrativo: todas entregan este hash.
#
#   Receivables::Row.normalize({ customer_name: 'Grúas', folio: 'A-1', due_on: '31/10/2026', balance: '$1,500.00', … })
#   → [{ customer_key:, customer_name:, rfc:, contact_name:, phone:, email:, folio:, issued_on:, due_on:, total:,
#        balance:, currency:, collector_email: }, nil]   o   [nil, 'motivo']
module Receivables::Row
  FIELDS = %i[customer_key customer_name rfc contact_name phone email folio issued_on due_on total balance currency
              collector_email].freeze
  REQUIRED = %i[customer_name folio due_on balance].freeze
  EXCEL_EPOCH = Date.new(1899, 12, 30)
  GENERIC_RFC = %w[XAXX010101000 XEXX010101000].freeze

  module_function

  CONVERT = { customer_key: :text, customer_name: :text, rfc: :rfc, contact_name: :text, phone: :phone, email: :email,
              folio: :text, issued_on: :date, due_on: :date, total: :amount, balance: :amount, currency: :currency,
              collector_email: :email }.freeze

  def normalize(raw)
    raw = raw.to_h.transform_keys(&:to_sym)
    row = CONVERT.to_h { |field, kind| [field, send(kind, raw[field])] }
    error = error_for(row, raw)
    error ? [nil, error] : [row, nil]
  end

  def error_for(row, raw)
    missing = REQUIRED.select { |f| row[f].blank? }
    return missing_text(missing, raw) if missing.any?
    return 'saldo negativo' if row[:balance].negative?

    'sin WhatsApp, correo, clave ni RFC para encontrarlo' if %i[phone email customer_key rfc].all? { |f| row[f].blank? }
  end

  def missing_text(missing, raw)
    raw.values.any?(&:present?) ? "falta #{missing.map { |f| LABELS[f] }.join(', ')}" : 'fila vacía'
  end

  LABELS = { customer_name: 'cliente', folio: 'folio', due_on: 'vencimiento (dd/mm/aaaa)', balance: 'saldo' }.freeze

  def text(value) = value.is_a?(Float) && (value % 1).zero? ? value.to_i.to_s : value.to_s.strip.presence

  def currency(value) = text(value).to_s.upcase.presence || 'MXN'

  def rfc(value)
    v = text(value).to_s.upcase.delete(' -')
    v.length.between?(12, 13) && GENERIC_RFC.exclude?(v) ? v : nil
  end

  # 10 dígitos (México) o el número con lada internacional: '+52 81 1234 5678' → '+528112345678'.
  def phone(value)
    digits = text(value).to_s.gsub(/\D/, '')
    return nil if digits.length < 10

    digits.length == 10 ? "+52#{digits}" : "+#{digits}"
  end

  def email(value)
    v = text(value).to_s.downcase
    v.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/) ? v : nil
  end

  # dd/mm/aaaa, aaaa-mm-dd o número de fecha de Excel.
  def date(value)
    return value.to_date if value.is_a?(Date) || value.is_a?(Time)
    return EXCEL_EPOCH + value.to_i if value.is_a?(Numeric)

    text_date(value.to_s.strip)
  end

  def text_date(text)
    return nil if text.empty?
    return EXCEL_EPOCH + text.to_i if text.match?(/\A\d{5}(\.\d+)?\z/)

    parts = text.split(%r{[/.-]})
    parts.size == 3 && parts.all? { |p| p.match?(/\A\d+\z/) } ? date_from(*parts.map(&:to_i)) : nil
  end

  # aaaa-mm-dd o dd/mm/aa(aa).
  def date_from(first, middle, last)
    return Date.new(first, middle, last) if first > 31

    Date.new(last < 100 ? last + 2000 : last, middle, first)
  rescue ArgumentError
    nil
  end

  # '$1,234.50' → 1234.5 · número tal cual · vacío → nil
  def amount(value)
    return value.to_d.round(2) if value.is_a?(Numeric)

    v = value.to_s.gsub(/[^\d.,-]/, '')
    return nil if v.empty?

    BigDecimal(decimal_point(v)).round(2)
  rescue ArgumentError
    nil
  end

  # El último separador manda: '1,234.50' y '1.234,50' → '1234.50'; '1,500' (miles) → '1500'; '12,5' → '12.5'.
  def decimal_point(text)
    last = [text.rindex('.'), text.rindex(',')].compact.max
    return text unless last

    decimals = text[(last + 1)..]
    return text.delete('.,') if decimals.length == 3 && text.count('.,') == 1 && text[last] == ','

    "#{text[0...last].delete('.,')}.#{decimals}"
  end
end
