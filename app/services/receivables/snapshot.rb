# frozen_string_literal: true

# Cobranza — aplicar un CORTE de la cartera. Es la puerta única por la que entra la cartera, venga de donde venga:
#   source 'upload'   un Excel/CSV subido (Receivables::Spreadsheet)
#   source 'microsip' / 'sae' / 'contpaqi' / …  la sincronización con el sistema administrativo (después, una por una):
#                     cada integración solo tiene que entregar filas con los campos de Receivables::Row.
#
# Reglas del corte (por fuente):
#   - factura nueva → se crea (evento «new»)
#   - baja de saldo → abono (evento «payment» con lo que bajó)
#   - saldo 0, o ya no viene en el corte de su misma fuente → pagada (evento «paid»)
#   - pagada que vuelve a traer saldo → reabierta
#
#   snap = Receivables::Snapshot.new(account, rows, source: 'upload', user: user, source_ref: 'cartera.xlsx')
#   snap.preview  → stats (no guarda nada: para el resumen antes de aplicar; Receivables::SnapshotStats)
#   snap.apply!   → el ReceivableImport con sus stats (y liga clientes y revisa promesas)
# rows: [[línea, { customer_name:, folio:, … }], …] o [{ … }, …]
class Receivables::Snapshot
  def initialize(account, rows, source: 'upload', user: nil, source_ref: nil)
    @account = account
    @source = source.to_s
    @user = user
    @source_ref = source_ref
    @rows = Receivables::SnapshotRows.new(rows)
  end

  def valid = @rows.valid

  def preview
    stats = Receivables::SnapshotStats.new(@rows)
    stats.call.merge(diff: stats.diff(existing_receivables), unlinked: unlinked_keys.size)
  end

  def apply!
    ActiveRecord::Base.transaction do
      @import = @account.receivable_imports.create!(user: @user, source: @source, source_ref: @source_ref)
      @changes = Hash.new(0)
      upsert_rows
      close_missing
      @import.update!(stats: Receivables::SnapshotStats.new(@rows).call.merge(diff: @changes.to_h))
    end
    after_apply
    @import.update!(stats: @import.stats.merge('unlinked' => @account.receivable_customers.pending.count))
    @import
  end

  private

  def existing_receivables
    @account.receivables.where(source: @source).includes(:receivable_customer)
  end

  def unlinked_keys
    known = @account.receivable_customers.where.not(link_status: 'pending').pluck(:external_key)
    valid.pluck(:key).uniq - known
  end

  # ---- aplicar ----

  def upsert_rows
    customers = @account.receivable_customers.where(external_key: valid.pluck(:key).uniq).index_by(&:external_key)
    valid.group_by { |r| r[:key] }.each do |key, rows|
      customer = customers[key] || @account.receivable_customers.new(external_key: key)
      update_customer(customer, rows.last)
      rows.each { |row| upsert_receivable(customer, row) }
    end
  end

  def update_customer(customer, row)
    customer.assign_attributes({ name: row[:customer_name], rfc: row[:rfc], contact_name: row[:contact_name], phone: row[:phone],
                                 email: row[:email], collector_id: collector_id(row[:collector_email]) }.compact)
    customer.save!
  end

  def collector_id(email)
    return nil if email.blank?

    @collectors ||= {}
    @collectors.fetch(email) { @collectors[email] = @account.users.where('LOWER(email) = ?', email.downcase).pick(:id) }
  end

  def upsert_receivable(customer, row)
    receivable = customer.receivables.find_or_initialize_by(account_id: @account.id, folio: row[:folio])
    before = [receivable.status, receivable.balance]
    receivable.assign_attributes(source: @source, issued_on: row[:issued_on], due_on: row[:due_on], total: row[:total],
                                 balance: row[:balance], currency: row[:currency], last_import_id: @import.id,
                                 status: row[:balance].zero? ? 'paid' : 'open')
    receivable.paid_at = receivable.status == 'paid' ? (receivable.paid_at || Time.current) : nil
    receivable.save!
    record(receivable, *before)
  end

  def record(receivable, before_status, before_balance)
    return event(receivable, 'new', receivable.balance) if receivable.previously_new_record? && receivable.status == 'open'
    return if receivable.previously_new_record?

    kind, amount = change_of(receivable, before_status, before_balance)
    event(receivable, kind, amount) if kind
  end

  def change_of(receivable, before_status, before_balance)
    return ['paid', before_balance] if before_status == 'open' && receivable.status == 'paid'
    return ['reopened', receivable.balance] if before_status == 'paid' && receivable.status == 'open'

    ['payment', before_balance - receivable.balance] if receivable.balance < before_balance
  end

  # Lo que ya no vino en el corte de esta misma fuente: pagado.
  def close_missing
    @account.receivables.where(source: @source, status: 'open').where.not(last_import_id: @import.id).find_each do |receivable|
      balance = receivable.balance
      receivable.update!(status: 'paid', paid_at: Time.current)
      event(receivable, 'paid', balance)
    end
  end

  def event(receivable, kind, amount)
    @changes[kind.to_sym] += 1
    @changes[:"#{kind}_amount"] += amount.to_f
    ReceivableEvent.create!(account_id: @account.id, receivable: receivable, receivable_import_id: @import.id, kind: kind,
                            amount: amount, created_at: Time.current)
  end

  def after_apply
    Receivables::Linker.new(@account).link_pending
    Receivables::Promises.reconcile(@account)
  end
end
