# frozen_string_literal: true

# Cobranza — el resumen de un corte: cuántos clientes y facturas, el total por moneda, la antigüedad de saldos y, en la
# vista previa, qué cambia contra lo que ya hay (nuevas, abonos, pagadas, reabiertas).
class Receivables::SnapshotStats
  BUCKETS = %w[not_due d1_15 d16_30 d31_60 d61_90 d90_plus].freeze

  def self.bucket(days)
    return 'not_due' if days <= 0
    return 'd1_15' if days <= 15
    return 'd16_30' if days <= 30
    return 'd31_60' if days <= 60

    days <= 90 ? 'd61_90' : 'd90_plus'
  end

  def initialize(rows, today: Date.current)
    @rows = rows
    @today = today
  end

  def call
    open = @rows.valid.select { |r| r[:balance].positive? }
    { rows: @rows.valid.size + @rows.rejected, valid: @rows.valid.size, errors: @rows.errors.first(200),
      customers: @rows.valid.pluck(:key).uniq.size, invoices: open.size,
      totals: sum_by(open) { |_r| 'total' }.transform_values { |h| h['total'] }, aging: sum_by(open) { |r| bucket_of(r) } }
  end

  # Contra lo que ya hay de esa fuente: { new:, payments:, payments_amount:, paid:, paid_amount:, reopened: }
  def diff(existing)
    current = existing.index_by { |r| [r.receivable_customer.external_key, r.folio.downcase] }
    incoming = @rows.valid.index_by { |r| [r[:key], r[:folio].downcase] }
    out = Hash.new(0)
    incoming.each { |key, row| change(out, current[key], row) }
    current.except(*incoming.keys).each_value { |old| add(out, :paid, old.balance) if old.status == 'open' }
    out.to_h
  end

  private

  def bucket_of(row) = self.class.bucket((@today - row[:due_on]).to_i)

  def sum_by(rows)
    rows.each_with_object({}) do |r, out|
      by = (out[r[:currency]] ||= Hash.new(0))
      by[yield(r)] += r[:balance].to_f
    end
  end

  def change(out, old, row)
    return out[:new] += 1 if old.nil? && row[:balance].positive?
    return if old.nil?
    return add(out, :paid, old.balance) if row[:balance].zero? && old.status == 'open'

    reopened_or_payment(out, old, row)
  end

  def reopened_or_payment(out, old, row)
    return out[:reopened] += 1 if old.status == 'paid' && row[:balance].positive?

    add(out, :payments, old.balance - row[:balance]) if row[:balance] < old.balance
  end

  def add(out, kind, amount)
    out[kind] += 1
    out[:"#{kind}_amount"] += amount.to_f
  end
end
