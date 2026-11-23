# frozen_string_literal: true

# Cobranza — el tablero: cuánto se debe y de cuándo, cuánto se cobró, promesas, comprobantes por validar, clientes por ligar
# y el último corte. También el resumen corto de un agente de cobranza (lista de Agentes listos).
module Receivables::Overview
  module_function

  def call(account, today: Date.current)
    open = account.receivables.open_balance
    { totals: open.group(:currency).sum(:balance).transform_values(&:to_f), aging: aging(open, today),
      on_hold: { disputed: open.where.not(disputed_at: nil).sum(:balance).to_f, claimed: open.where.not(claimed_at: nil).sum(:balance).to_f },
      collected_30: collected(account, 30.days.ago), customers: customers(account), promises: promises(account),
      claims_pending: account.payment_claims.pending.count, last_import: last_import(account) }
  end

  def aging(scope, today)
    scope.pluck(:currency, :due_on, :balance).each_with_object({}) do |(currency, due_on, balance), out|
      bucket = Receivables::SnapshotStats.bucket((today - due_on).to_i)
      (out[currency] ||= Receivables::SnapshotStats::BUCKETS.index_with { 0.0 })[bucket] += balance.to_f
    end
  end

  def collected(account, since)
    ReceivableEvent.where(account_id: account.id, kind: %w[payment paid]).where('receivable_events.created_at >= ?', since)
                   .joins(:receivable).group('receivables.currency').sum(:amount).transform_values(&:to_f)
  end

  def customers(account)
    with_balance = account.receivable_customers.joins(:receivables).merge(Receivable.open_balance).distinct
    { with_balance: with_balance.count, pending_link: account.receivable_customers.pending.joins(:receivables)
                                                             .merge(Receivable.open_balance).distinct.count,
      contacted_7: account.receivable_customers.where('last_contacted_at >= ?', 7.days.ago).count }
  end

  def promises(account)
    recent = account.payment_promises.where('created_at >= ?', 30.days.ago)
    { pending: account.payment_promises.pending.count, kept: recent.where(status: 'kept').count, broken: recent.where(status: 'broken').count }
  end

  def last_import(account)
    import = account.receivable_imports.order(created_at: :desc).first
    import&.slice(:id, :source, :source_ref, :created_at)&.merge(stats: import.stats.slice('valid', 'customers', 'invoices', 'diff'))
  end

  # Lo que se ve del agente en la lista: a cuántos les cobra, a cuántos les escribió esta semana.
  def agent(template)
    account = template.account
    { with_balance: customers(account)[:with_balance], contacted_7: account.receivable_customers.where('last_contacted_at >= ?', 7.days.ago).count,
      outreach_on: template.motor2.to_h.dig('answers', 'outreach_on') == true }
  end
end
